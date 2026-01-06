import { Router, Request, Response } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import {
  uploadProfilePicture,
  uploadDocument,
  uploadSignInSheet,
  getPresignedUrl,
  deleteFile,
  extractKeyFromUrl,
  isStorageConfigured,
} from '../services/storageService';
import { UserModel } from '../models/user';
import { ManagerModel } from '../models/manager';
import { EventModel } from '../models/event';
import pino from 'pino';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
const router = Router();

// Configure multer for memory storage (files stored in buffer)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
  },
  fileFilter: (_req, file, cb) => {
    // Allow images and PDFs
    const allowedMimes = [
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'application/pdf',
    ];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Allowed: JPEG, PNG, WebP, HEIC, PDF'));
    }
  },
});

// Middleware to check if storage is configured
function requireStorageConfigured(req: Request, res: Response, next: Function) {
  if (!isStorageConfigured()) {
    return res.status(503).json({
      message: 'File storage is not configured',
    });
  }
  next();
}

/**
 * POST /upload/profile-picture
 * Upload or update profile picture for the authenticated user
 */
router.post(
  '/profile-picture',
  requireAuth,
  requireStorageConfigured,
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      const file = req.file;
      if (!file) {
        return res.status(400).json({ message: 'No file provided' });
      }

      const { provider, sub, managerId } = (req as any).authUser;

      // Determine if this is a manager or user upload
      const isManager = !!managerId;
      const ownerId = isManager ? managerId : `${provider}:${sub}`;

      // Upload the file
      const url = await uploadProfilePicture(
        file.buffer,
        ownerId,
        file.originalname,
        file.mimetype
      );

      // Update the user/manager document with the new picture URL
      if (isManager) {
        const oldManager = await ManagerModel.findById(managerId);
        const oldPictureUrl = oldManager?.picture;

        await ManagerModel.findByIdAndUpdate(managerId, { picture: url });

        // Delete old picture if it was an R2 URL
        if (oldPictureUrl) {
          const oldKey = extractKeyFromUrl(oldPictureUrl);
          if (oldKey) {
            try {
              await deleteFile(oldKey);
            } catch (e) {
              logger.warn({ oldKey }, 'Failed to delete old profile picture');
            }
          }
        }
      } else {
        const oldUser = await UserModel.findOne({ provider, subject: sub });
        const oldPictureUrl = oldUser?.picture;

        await UserModel.updateOne(
          { provider, subject: sub },
          { picture: url }
        );

        // Delete old picture if it was an R2 URL
        if (oldPictureUrl) {
          const oldKey = extractKeyFromUrl(oldPictureUrl);
          if (oldKey) {
            try {
              await deleteFile(oldKey);
            } catch (e) {
              logger.warn({ oldKey }, 'Failed to delete old profile picture');
            }
          }
        }
      }

      logger.info({ ownerId, isManager }, 'Profile picture uploaded');

      return res.json({
        url,
        message: 'Profile picture uploaded successfully',
      });
    } catch (error) {
      logger.error({ error }, 'Failed to upload profile picture');
      return res.status(500).json({ message: 'Failed to upload profile picture' });
    }
  }
);

/**
 * POST /upload/document
 * Upload a document (PDF, contract, etc.) - Manager only
 */
router.post(
  '/document',
  requireAuth,
  requireStorageConfigured,
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      const file = req.file;
      if (!file) {
        return res.status(400).json({ message: 'No file provided' });
      }

      const { managerId } = (req as any).authUser;
      if (!managerId) {
        return res.status(403).json({ message: 'Only managers can upload documents' });
      }

      const result = await uploadDocument(
        file.buffer,
        managerId,
        file.originalname,
        file.mimetype
      );

      logger.info({ managerId, key: result.key }, 'Document uploaded');

      return res.json({
        key: result.key,
        url: result.url,
        filename: file.originalname,
        contentType: file.mimetype,
        size: file.size,
        message: 'Document uploaded successfully',
      });
    } catch (error) {
      logger.error({ error }, 'Failed to upload document');
      return res.status(500).json({ message: 'Failed to upload document' });
    }
  }
);

/**
 * POST /upload/sign-in-sheet/:eventId
 * Upload a sign-in sheet photo for an event - Manager only
 */
router.post(
  '/sign-in-sheet/:eventId',
  requireAuth,
  requireStorageConfigured,
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      const file = req.file;
      if (!file) {
        return res.status(400).json({ message: 'No file provided' });
      }

      const { managerId } = (req as any).authUser;
      if (!managerId) {
        return res.status(403).json({ message: 'Only managers can upload sign-in sheets' });
      }

      const { eventId } = req.params;

      // Verify the event belongs to this manager
      const event = await EventModel.findOne({
        _id: eventId,
        managerId: managerId,
      });

      if (!event) {
        return res.status(404).json({ message: 'Event not found' });
      }

      // Upload the sign-in sheet
      const url = await uploadSignInSheet(
        file.buffer,
        eventId,
        file.originalname,
        file.mimetype
      );

      // Update the event with the sign-in sheet URL
      const oldUrl = event.signInSheetPhotoUrl;
      await EventModel.findByIdAndUpdate(eventId, {
        signInSheetPhotoUrl: url,
        hoursSubmittedAt: new Date(),
        hoursSubmittedBy: managerId,
      });

      // Delete old sign-in sheet if exists
      if (oldUrl) {
        const oldKey = extractKeyFromUrl(oldUrl);
        if (oldKey) {
          try {
            await deleteFile(oldKey);
          } catch (e) {
            logger.warn({ oldKey }, 'Failed to delete old sign-in sheet');
          }
        }
      }

      logger.info({ managerId, eventId }, 'Sign-in sheet uploaded');

      return res.json({
        url,
        eventId,
        message: 'Sign-in sheet uploaded successfully',
      });
    } catch (error) {
      logger.error({ error }, 'Failed to upload sign-in sheet');
      return res.status(500).json({ message: 'Failed to upload sign-in sheet' });
    }
  }
);

/**
 * GET /upload/presigned-url
 * Get a presigned URL for downloading a private file
 */
const presignedUrlSchema = z.object({
  key: z.string().min(1),
  expiresIn: z.coerce.number().min(60).max(86400).optional().default(3600),
});

router.get(
  '/presigned-url',
  requireAuth,
  requireStorageConfigured,
  async (req: Request, res: Response) => {
    try {
      const parsed = presignedUrlSchema.safeParse(req.query);
      if (!parsed.success) {
        return res.status(400).json({
          message: 'Invalid query parameters',
          errors: parsed.error.errors,
        });
      }

      const { key, expiresIn } = parsed.data;
      const { managerId } = (req as any).authUser;

      // For documents, verify the manager owns the file
      if (key.startsWith('documents/') && managerId) {
        const keyManagerId = key.split('/')[1];
        if (keyManagerId !== managerId) {
          return res.status(403).json({ message: 'Access denied' });
        }
      }

      const url = await getPresignedUrl(key, expiresIn);

      return res.json({ url, expiresIn });
    } catch (error) {
      logger.error({ error }, 'Failed to generate presigned URL');
      return res.status(500).json({ message: 'Failed to generate download URL' });
    }
  }
);

/**
 * DELETE /upload/file
 * Delete a file from storage - Only owner can delete
 */
router.delete(
  '/file',
  requireAuth,
  requireStorageConfigured,
  async (req: Request, res: Response) => {
    try {
      const { key } = req.body;
      if (!key || typeof key !== 'string') {
        return res.status(400).json({ message: 'File key is required' });
      }

      const { provider, sub, managerId } = (req as any).authUser;
      const userKey = `${provider}:${sub}`;

      // Verify ownership based on key structure
      const keyParts = key.split('/');
      if (keyParts.length < 2) {
        return res.status(400).json({ message: 'Invalid file key' });
      }

      const [category, ownerId] = keyParts;

      // Check ownership
      let authorized = false;
      if (category === 'profiles') {
        authorized = ownerId === managerId || ownerId === userKey;
      } else if (category === 'documents') {
        authorized = ownerId === managerId;
      } else if (category === 'sign-in-sheets') {
        // Check if manager owns the event
        const event = await EventModel.findById(ownerId);
        authorized = event?.managerId?.toString() === managerId;
      }

      if (!authorized) {
        return res.status(403).json({ message: 'Access denied' });
      }

      await deleteFile(key);

      return res.json({ message: 'File deleted successfully' });
    } catch (error) {
      logger.error({ error }, 'Failed to delete file');
      return res.status(500).json({ message: 'Failed to delete file' });
    }
  }
);

export default router;
