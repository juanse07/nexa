import crypto from 'crypto';

/**
 * Generate a cryptographically random refresh token (base64url, 48 bytes = 384 bits).
 */
export function generateRefreshToken(): string {
  return crypto.randomBytes(48).toString('base64url');
}

/**
 * Hash a refresh token with SHA-256 for storage.
 * Refresh tokens are high-entropy (384 bits) so SHA-256 is sufficient —
 * bcrypt's slowness only helps for low-entropy inputs like passwords.
 */
export function hashRefreshToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}
