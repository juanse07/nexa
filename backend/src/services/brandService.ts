/**
 * Brand customization service — logo processing + AI color extraction.
 */

import sharp from 'sharp';
import axios from 'axios';
import pino from 'pino';
import { uploadBrandAsset, getPresignedUrl } from './storageService';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

export interface LogoProcessResult {
  originalUrl: string;
  originalKey: string;
  headerUrl: string;
  headerKey: string;
  watermarkUrl: string;
  watermarkKey: string;
  aspectRatio: number;
  shapeClassification: 'horizontal' | 'square' | 'vertical' | 'icon';
}

export interface ExtractedColors {
  primaryColor: string;
  secondaryColor: string;
  accentColor: string;
  neutralColor: string;
}

type ShapeClassification = 'horizontal' | 'square' | 'vertical' | 'icon';

function classifyShape(width: number, height: number): ShapeClassification {
  const ratio = width / height;
  if (ratio > 2) return 'horizontal';
  if (ratio >= 0.8) return 'square';
  if (ratio >= 0.4) return 'vertical';
  return 'icon';
}

/**
 * Process an uploaded logo: generate header + watermark variants, upload all to R2.
 */
export async function processLogo(
  buffer: Buffer,
  managerId: string,
  filename: string,
  mimeType: string,
): Promise<LogoProcessResult> {
  // Get metadata
  const metadata = await sharp(buffer).metadata();
  const width = metadata.width || 100;
  const height = metadata.height || 100;
  const aspectRatio = Math.round((width / height) * 100) / 100;
  const shapeClassification = classifyShape(width, height);

  const baseName = filename.replace(/\.[^.]+$/, '');

  // Upload original
  const original = await uploadBrandAsset(buffer, managerId, `${baseName}-original.png`, mimeType);

  // Generate header variant (max 300x80px, PNG)
  const headerBuffer = await sharp(buffer)
    .resize({ width: 300, height: 80, fit: 'inside', withoutEnlargement: true })
    .png()
    .toBuffer();
  const header = await uploadBrandAsset(headerBuffer, managerId, `${baseName}-header.png`, 'image/png');

  // Generate watermark variant (max 200x200px, PNG)
  const watermarkBuffer = await sharp(buffer)
    .resize({ width: 200, height: 200, fit: 'inside', withoutEnlargement: true })
    .png()
    .toBuffer();
  const watermark = await uploadBrandAsset(watermarkBuffer, managerId, `${baseName}-watermark.png`, 'image/png');

  return {
    originalUrl: original.url,
    originalKey: original.key,
    headerUrl: header.url,
    headerKey: header.key,
    watermarkUrl: watermark.url,
    watermarkKey: watermark.key,
    aspectRatio,
    shapeClassification,
  };
}

/**
 * Extract brand colors from a logo using Groq Llama 4 Scout vision model.
 * Falls back to defaults on failure.
 */
export async function extractColorsFromLogo(imageBuffer: Buffer): Promise<ExtractedColors> {
  const defaults: ExtractedColors = {
    primaryColor: '#1e293b',
    secondaryColor: '#334155',
    accentColor: '#3b82f6',
    neutralColor: '#f8fafc',
  };

  const groqKey = process.env.GROQ_API_KEY;
  if (!groqKey) {
    logger.warn('GROQ_API_KEY not set — returning default brand colors');
    return defaults;
  }

  try {
    const base64 = imageBuffer.toString('base64');
    const mimeType = 'image/png';
    const dataUrl = `data:${mimeType};base64,${base64}`;

    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'meta-llama/llama-4-scout-17b-16e-instruct',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Analyze this logo image. Extract 4 hex colors that form a brand palette:\n' +
                  '1. primary — dominant/darkest brand color (for headers/backgrounds)\n' +
                  '2. secondary — complementary darker color (for subheadings/borders)\n' +
                  '3. accent — vibrant highlight color (for buttons/links)\n' +
                  '4. neutral — very light tint derived from the brand (for alternating row backgrounds)\n\n' +
                  'Return ONLY valid JSON: {"primaryColor":"#hex","secondaryColor":"#hex","accentColor":"#hex","neutralColor":"#hex"}',
              },
              {
                type: 'image_url',
                image_url: { url: dataUrl },
              },
            ],
          },
        ],
        max_tokens: 200,
        temperature: 0.1,
      },
      {
        headers: {
          Authorization: `Bearer ${groqKey}`,
          'Content-Type': 'application/json',
        },
        timeout: 15000,
      },
    );

    const content = response.data?.choices?.[0]?.message?.content || '';
    logger.info({ raw: content }, '[brandService] Groq vision response');

    // Extract JSON from response (may be wrapped in markdown code block)
    const jsonMatch = content.match(/\{[^}]+\}/);
    if (!jsonMatch) {
      logger.warn('[brandService] No JSON found in Groq response');
      return defaults;
    }

    const parsed = JSON.parse(jsonMatch[0]);

    // Validate hex format
    const hexPattern = /^#[0-9a-fA-F]{6}$/;
    const result: ExtractedColors = {
      primaryColor: hexPattern.test(parsed.primaryColor) ? parsed.primaryColor : defaults.primaryColor,
      secondaryColor: hexPattern.test(parsed.secondaryColor) ? parsed.secondaryColor : defaults.secondaryColor,
      accentColor: hexPattern.test(parsed.accentColor) ? parsed.accentColor : defaults.accentColor,
      neutralColor: hexPattern.test(parsed.neutralColor) ? parsed.neutralColor : defaults.neutralColor,
    };

    return result;
  } catch (err: any) {
    logger.error({ err: err.message }, '[brandService] Color extraction failed — using defaults');
    return defaults;
  }
}
