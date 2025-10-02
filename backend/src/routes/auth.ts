import { Router } from 'express';
import { OAuth2Client } from 'google-auth-library';
import * as jose from 'jose';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env';
import { UserModel } from '../models/user';

type VerifiedProfile = {
  provider: 'google' | 'apple';
  subject: string;
  email?: string | undefined;
  name?: string | undefined;
  picture?: string | undefined;
};

const router = Router();

const GOOGLE_CLIENT_ID_IOS = ENV.googleClientIdIos;
const GOOGLE_CLIENT_ID_ANDROID = ENV.googleClientIdAndroid;
const GOOGLE_CLIENT_ID_WEB = ENV.googleClientIdWeb;
const GOOGLE_SERVER_CLIENT_ID = ENV.googleServerClientId;
const APPLE_BUNDLE_ID = ENV.appleBundleId;
const JWT_SECRET = ENV.jwtSecret;

if (!JWT_SECRET) {
  // eslint-disable-next-line no-console
  console.warn('[auth] BACKEND_JWT_SECRET is not set. Using auth routes will fail.');
}
if (!GOOGLE_CLIENT_ID_IOS) {
  // eslint-disable-next-line no-console
  console.warn('[auth] GOOGLE_CLIENT_ID_IOS is not set. Google sign-in will fail.');
}
if (!GOOGLE_CLIENT_ID_ANDROID) {
  // eslint-disable-next-line no-console
  console.warn('[auth] GOOGLE_CLIENT_ID_ANDROID is not set. Android Google sign-in may fail.');
}
if (!GOOGLE_SERVER_CLIENT_ID) {
  // eslint-disable-next-line no-console
  console.warn('[auth] GOOGLE_SERVER_CLIENT_ID not set. Using only platform client IDs.');
}

function issueAppJwt(profile: VerifiedProfile): string {
  const payload = {
    sub: profile.subject,
    provider: profile.provider,
    email: profile.email,
    name: profile.name,
    picture: profile.picture,
  } as const;
  return jwt.sign(payload, JWT_SECRET, { algorithm: 'HS256', expiresIn: '7d' });
}

async function upsertUser(profile: VerifiedProfile) {
  const filter = { provider: profile.provider, subject: profile.subject } as const;
  const update = {
    $set: {
      provider: profile.provider,
      subject: profile.subject,
      email: profile.email,
      name: profile.name,
      picture: profile.picture,
      updatedAt: new Date(),
    },
    $setOnInsert: { createdAt: new Date() },
  } as const;
  await UserModel.updateOne(filter, update, { upsert: true });
}

async function verifyGoogleIdToken(idToken: string): Promise<VerifiedProfile> {
  // Accept tokens from iOS, Android, Web, or Server client IDs
  const audience = [
    GOOGLE_CLIENT_ID_IOS,
    GOOGLE_CLIENT_ID_ANDROID,
    GOOGLE_CLIENT_ID_WEB,
    GOOGLE_SERVER_CLIENT_ID,
  ].filter(Boolean);

  if (audience.length === 0) {
    throw new Error('No Google Client IDs configured on server');
  }

  const client = new OAuth2Client();
  const ticket = await client.verifyIdToken({ idToken, audience });
  const payload = ticket.getPayload();
  if (!payload || !payload.sub) {
    throw new Error('Invalid Google token');
  }
  return {
    provider: 'google',
    subject: payload.sub,
    email: payload.email ?? undefined,
    name: payload.name ?? undefined,
    picture: payload.picture ?? undefined,
  };
}

async function verifyAppleIdentityToken(identityToken: string): Promise<VerifiedProfile> {
  const JWKS = jose.createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
  const options: jose.JWTVerifyOptions = APPLE_BUNDLE_ID
    ? { issuer: 'https://appleid.apple.com', audience: APPLE_BUNDLE_ID }
    : { issuer: 'https://appleid.apple.com' };
  const { payload } = await jose.jwtVerify(identityToken, JWKS, options);
  const subject = payload.sub as string | undefined;
  if (!subject) {
    throw new Error('Invalid Apple token');
  }
  return {
    provider: 'apple',
    subject,
    email: (payload.email as string | undefined) ?? undefined,
    name: undefined,
    picture: undefined,
  };
}

router.post('/google', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });
    const idToken = (req.body?.idToken ?? '') as string;
    if (!idToken) return res.status(400).json({ message: 'idToken is required' });
    const profile = await verifyGoogleIdToken(idToken);
    await upsertUser(profile);
    const token = issueAppJwt(profile);
    res.json({ token, user: profile });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Google verification failed:', err);
    res.status(401).json({ message: 'Google auth failed' });
  }
});

router.post('/apple', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });
    const identityToken = (req.body?.identityToken ?? '') as string;
    if (!identityToken) return res.status(400).json({ message: 'identityToken is required' });
    const profile = await verifyAppleIdentityToken(identityToken);
    await upsertUser(profile);
    const token = issueAppJwt(profile);
    res.json({ token, user: profile });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Apple verification failed:', err);
    res.status(401).json({ message: 'Apple auth failed' });
  }
});

export default router;


