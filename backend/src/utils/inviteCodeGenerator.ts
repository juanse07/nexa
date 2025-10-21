import crypto from 'crypto';
import { TeamInviteModel } from '../models/teamInvite';

// Use characters that are unambiguous (exclude I, O, 0, 1 to avoid confusion)
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;

/**
 * Generates a unique 6-character invite code.
 * Codes use uppercase letters and numbers, excluding confusing characters (I, O, 0, 1).
 *
 * @returns Promise<string> Unique 6-character code like "ABC123"
 * @throws Error if unable to generate unique code after max attempts
 */
export async function generateUniqueShortCode(): Promise<string> {
  const maxAttempts = 10;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const code = generateRandomCode();

    // Check if code already exists in database
    const existing = await TeamInviteModel.findOne({ shortCode: code }).lean();

    if (!existing) {
      return code;
    }

    // Code collision, try again
  }

  throw new Error('Failed to generate unique invite code after ' + maxAttempts + ' attempts');
}

/**
 * Generates a random 6-character code using secure random number generation.
 *
 * @returns string Random code like "ABC123"
 */
function generateRandomCode(): string {
  let code = '';

  for (let i = 0; i < CODE_LENGTH; i++) {
    const randomIndex = crypto.randomInt(0, CODE_CHARS.length);
    code += CODE_CHARS[randomIndex];
  }

  return code;
}

/**
 * Validates that a short code matches the expected format.
 *
 * @param code Code to validate
 * @returns boolean True if valid format
 */
export function isValidShortCodeFormat(code: string): boolean {
  if (!code || typeof code !== 'string') {
    return false;
  }

  // Must be exactly 6 characters
  if (code.length !== CODE_LENGTH) {
    return false;
  }

  // Must only contain valid characters
  const codeUpper = code.toUpperCase();
  for (const char of codeUpper) {
    if (!CODE_CHARS.includes(char)) {
      return false;
    }
  }

  return true;
}
