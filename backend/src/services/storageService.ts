import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { ENV } from '../config/env';
import pino from 'pino';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

// Cloudflare R2 uses S3-compatible API
const r2Client = new S3Client({
  region: 'auto',
  endpoint: `https://${ENV.r2AccountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: ENV.r2AccessKeyId,
    secretAccessKey: ENV.r2SecretAccessKey,
  },
});

export type FileCategory = 'profiles' | 'documents' | 'sign-in-sheets';

interface UploadResult {
  key: string;
  url: string;
}

/**
 * Generates a storage key for a file
 * Format: {category}/{ownerId}/{filename}
 */
function generateKey(
  category: FileCategory,
  ownerId: string,
  filename: string
): string {
  // Sanitize filename to remove special characters
  const sanitized = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
  const timestamp = Date.now();
  return `${category}/${ownerId}/${timestamp}-${sanitized}`;
}

/**
 * Uploads a file to Cloudflare R2
 */
export async function uploadFile(
  buffer: Buffer,
  category: FileCategory,
  ownerId: string,
  filename: string,
  contentType: string
): Promise<UploadResult> {
  const key = generateKey(category, ownerId, filename);

  try {
    await r2Client.send(
      new PutObjectCommand({
        Bucket: ENV.r2BucketName,
        Key: key,
        Body: buffer,
        ContentType: contentType,
        // Make profile pictures publicly readable
        ...(category === 'profiles' && { ACL: 'public-read' }),
      })
    );

    // Construct the public URL
    const url = ENV.r2PublicUrl
      ? `${ENV.r2PublicUrl}/${key}`
      : `https://${ENV.r2BucketName}.${ENV.r2AccountId}.r2.cloudflarestorage.com/${key}`;

    logger.info({ key, category, ownerId }, 'File uploaded to R2');

    return { key, url };
  } catch (error) {
    logger.error({ error, key, category }, 'Failed to upload file to R2');
    throw new Error('Failed to upload file');
  }
}

/**
 * Uploads a profile picture and returns the public URL
 */
export async function uploadProfilePicture(
  buffer: Buffer,
  userId: string,
  filename: string,
  contentType: string
): Promise<string> {
  const result = await uploadFile(buffer, 'profiles', userId, filename, contentType);
  return result.url;
}

/**
 * Uploads a document (PDF, contract, etc.) and returns the URL
 */
export async function uploadDocument(
  buffer: Buffer,
  managerId: string,
  filename: string,
  contentType: string
): Promise<UploadResult> {
  return uploadFile(buffer, 'documents', managerId, filename, contentType);
}

/**
 * Uploads a sign-in sheet photo and returns the URL
 */
export async function uploadSignInSheet(
  buffer: Buffer,
  eventId: string,
  filename: string,
  contentType: string
): Promise<string> {
  const result = await uploadFile(buffer, 'sign-in-sheets', eventId, filename, contentType);
  return result.url;
}

/**
 * Generates a presigned URL for private file access (e.g., documents)
 * URL expires after specified seconds (default 1 hour)
 */
export async function getPresignedUrl(
  key: string,
  expiresInSeconds: number = 3600
): Promise<string> {
  try {
    const command = new GetObjectCommand({
      Bucket: ENV.r2BucketName,
      Key: key,
    });

    const url = await getSignedUrl(r2Client, command, {
      expiresIn: expiresInSeconds,
    });

    return url;
  } catch (error) {
    logger.error({ error, key }, 'Failed to generate presigned URL');
    throw new Error('Failed to generate download URL');
  }
}

/**
 * Deletes a file from R2
 */
export async function deleteFile(key: string): Promise<void> {
  try {
    await r2Client.send(
      new DeleteObjectCommand({
        Bucket: ENV.r2BucketName,
        Key: key,
      })
    );
    logger.info({ key }, 'File deleted from R2');
  } catch (error) {
    logger.error({ error, key }, 'Failed to delete file from R2');
    throw new Error('Failed to delete file');
  }
}

/**
 * Extracts the key from a full R2 URL
 */
export function extractKeyFromUrl(url: string): string | null {
  if (!url) return null;

  // Try to extract key from various URL formats
  const patterns = [
    // Custom domain: https://files.example.com/profiles/123/avatar.jpg
    new RegExp(`${ENV.r2PublicUrl}/(.+)`),
    // R2 dev URL: https://pub-xxx.r2.dev/profiles/123/avatar.jpg
    /https:\/\/pub-[a-z0-9]+\.r2\.dev\/(.+)/,
    // Direct R2 URL
    new RegExp(`${ENV.r2BucketName}\\.[^/]+\\.r2\\.cloudflarestorage\\.com/(.+)`),
  ];

  for (const pattern of patterns) {
    const match = url.match(pattern);
    if (match && match[1]) {
      return match[1];
    }
  }

  return null;
}

/**
 * Checks if R2 storage is properly configured
 */
export function isStorageConfigured(): boolean {
  return !!(
    ENV.r2AccountId &&
    ENV.r2AccessKeyId &&
    ENV.r2SecretAccessKey &&
    ENV.r2BucketName
  );
}
