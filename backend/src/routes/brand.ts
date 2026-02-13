import { Router } from 'express';
import { z } from 'zod';
import multer from 'multer';
import { requireAuth } from '../middleware/requireAuth';
import { resolveManagerForRequest } from '../utils/manager';
import { processLogo, extractColorsFromLogo } from '../services/brandService';
import { deleteFile, extractKeyFromUrl, getPresignedUrl } from '../services/storageService';

const router = Router();

// Multer: in-memory, 5MB max, images only
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Allowed: JPEG, PNG, WebP'));
    }
  },
});

// Zod schema for manual color override
const ColorUpdateSchema = z.object({
  primaryColor: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  secondaryColor: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  accentColor: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  neutralColor: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
});

/**
 * POST /brand/logo
 * Upload logo, process variants, extract colors via AI, save to manager.
 */
router.post('/logo', requireAuth, upload.single('logo'), async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);

    if (!req.file) {
      return res.status(400).json({ message: 'No logo file provided' });
    }

    console.log(`[brand/logo] Processing logo for manager ${manager._id} (${req.file.originalname}, ${req.file.size} bytes)`);

    // Process logo variants (original, header, watermark)
    const logoResult = await processLogo(
      req.file.buffer,
      String(manager._id),
      req.file.originalname,
      req.file.mimetype,
    );

    // Extract colors via AI vision
    const colors = await extractColorsFromLogo(req.file.buffer);

    // Save to manager (preserve preferredDocDesign if it was set)
    const now = new Date();
    const existingDesign = manager.brandProfile?.preferredDocDesign;
    manager.brandProfile = {
      logoOriginalUrl: logoResult.originalUrl,
      logoHeaderUrl: logoResult.headerUrl,
      logoWatermarkUrl: logoResult.watermarkUrl,
      aspectRatio: logoResult.aspectRatio,
      shapeClassification: logoResult.shapeClassification,
      primaryColor: colors.primaryColor,
      secondaryColor: colors.secondaryColor,
      accentColor: colors.accentColor,
      neutralColor: colors.neutralColor,
      preferredDocDesign: existingDesign || 'classic',
      createdAt: manager.brandProfile?.createdAt || now,
      updatedAt: now,
    };
    await manager.save();

    console.log(`[brand/logo] Brand profile saved for manager ${manager._id}`);

    return res.json({
      message: 'Logo uploaded and colors extracted',
      brandProfile: manager.brandProfile,
    });
  } catch (err: any) {
    console.error('[brand/logo] Error:', err);
    return res.status(500).json({ message: 'Failed to process logo', error: err.message });
  }
});

/**
 * PUT /brand/colors
 * Manual color override.
 */
router.put('/colors', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);

    const parsed = ColorUpdateSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid colors', errors: parsed.error.issues });
    }

    if (!manager.brandProfile) {
      manager.brandProfile = { createdAt: new Date(), updatedAt: new Date() };
    }

    const updates = parsed.data;
    if (updates.primaryColor) manager.brandProfile.primaryColor = updates.primaryColor;
    if (updates.secondaryColor) manager.brandProfile.secondaryColor = updates.secondaryColor;
    if (updates.accentColor) manager.brandProfile.accentColor = updates.accentColor;
    if (updates.neutralColor) manager.brandProfile.neutralColor = updates.neutralColor;
    manager.brandProfile.updatedAt = new Date();

    await manager.save();

    return res.json({
      message: 'Colors updated',
      brandProfile: manager.brandProfile,
    });
  } catch (err: any) {
    console.error('[brand/colors] Error:', err);
    return res.status(500).json({ message: 'Failed to update colors', error: err.message });
  }
});

// Zod schema for doc design preference
const DocDesignSchema = z.object({
  design: z.enum(['plain', 'classic', 'executive']),
});

/**
 * PUT /brand/doc-design
 * Save preferred document design template.
 */
router.put('/doc-design', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);

    const parsed = DocDesignSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid design', errors: parsed.error.issues });
    }

    if (!manager.brandProfile) {
      manager.brandProfile = { createdAt: new Date(), updatedAt: new Date() };
    }

    manager.brandProfile.preferredDocDesign = parsed.data.design;
    manager.brandProfile.updatedAt = new Date();
    await manager.save();

    return res.json({
      message: 'Document design updated',
      preferredDocDesign: parsed.data.design,
    });
  } catch (err: any) {
    console.error('[brand/doc-design] Error:', err);
    return res.status(500).json({ message: 'Failed to update design', error: err.message });
  }
});

/**
 * GET /brand/profile
 * Get current brand profile.
 */
router.get('/profile', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);

    if (!manager.brandProfile) {
      return res.json({ brandProfile: null });
    }

    // Use toObject() for clean serialization (avoids Mongoose internal properties)
    const fullDoc = manager.toObject();
    const profile = fullDoc.brandProfile;

    return res.json({ brandProfile: profile });
  } catch (err: any) {
    console.error('[brand/profile] Error:', err);
    return res.status(500).json({ message: 'Failed to get brand profile', error: err.message });
  }
});

/**
 * DELETE /brand/profile
 * Remove brand profile and delete R2 assets.
 */
router.delete('/profile', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);

    if (!manager.brandProfile) {
      return res.json({ message: 'No brand profile to remove' });
    }

    // Delete R2 assets
    const urls = [
      manager.brandProfile.logoOriginalUrl,
      manager.brandProfile.logoHeaderUrl,
      manager.brandProfile.logoWatermarkUrl,
    ];

    for (const url of urls) {
      if (url) {
        const key = extractKeyFromUrl(url);
        if (key) {
          try {
            await deleteFile(key);
          } catch {
            // Best-effort deletion
          }
        }
      }
    }

    manager.brandProfile = undefined;
    await manager.save();

    console.log(`[brand/profile] Brand profile removed for manager ${manager._id}`);

    return res.json({ message: 'Brand profile removed' });
  } catch (err: any) {
    console.error('[brand/profile] Error:', err);
    return res.status(500).json({ message: 'Failed to remove brand profile', error: err.message });
  }
});

export default router;
