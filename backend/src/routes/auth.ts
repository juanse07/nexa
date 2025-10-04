import { Router } from 'express';
import { OAuth2Client } from 'google-auth-library';
import * as jose from 'jose';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env';
import { UserModel } from '../models/user';
import { ManagerModel } from '../models/manager';

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
const APPLE_BUNDLE_IDS = ENV.appleBundleId;
const JWT_SECRET = ENV.jwtSecret;

if (!JWT_SECRET) {
  // eslint-disable-next-line no-console
  console.warn('[auth] BACKEND_JWT_SECRET is not set. Using auth routes will fail.');
}
if (GOOGLE_CLIENT_ID_IOS.length === 0) {
  // eslint-disable-next-line no-console
  console.warn('[auth] GOOGLE_CLIENT_ID_IOS is not set. Google sign-in will fail.');
}
if (GOOGLE_CLIENT_ID_ANDROID.length === 0) {
  // eslint-disable-next-line no-console
  console.warn('[auth] GOOGLE_CLIENT_ID_ANDROID is not set. Android Google sign-in may fail.');
}
if (GOOGLE_SERVER_CLIENT_ID.length === 0) {
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

async function ensureManagerDocument(profile: VerifiedProfile) {
  const filter = { provider: profile.provider, subject: profile.subject } as const;
  const name = (profile.name || '').trim();
  const first_name = name ? name.split(/\s+/).slice(0, -1).join(' ') || undefined : undefined;
  const last_name = name ? name.split(/\s+/).slice(-1)[0] || undefined : undefined;
  await ManagerModel.updateOne(
    filter,
    {
      // Always refresh missing basic fields if currently empty
      $setOnInsert: {
        provider: profile.provider,
        subject: profile.subject,
        email: profile.email,
        name: profile.name,
        first_name,
        last_name,
        picture: profile.picture,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      $set: {
        updatedAt: new Date(),
        ...(profile.email ? { email: profile.email } : {}),
        ...(profile.name ? { name: profile.name } : {}),
        ...(first_name ? { first_name } : {}),
        ...(last_name ? { last_name } : {}),
        ...(profile.picture ? { picture: profile.picture } : {}),
      },
    },
    { upsert: true }
  );
}

async function verifyGoogleIdToken(idToken: string): Promise<VerifiedProfile> {
  // Accept tokens from iOS, Android, Web, or Server client IDs
  // Each can be an array of client IDs to support multiple apps
  const audience = [
    ...GOOGLE_CLIENT_ID_IOS,
    ...GOOGLE_CLIENT_ID_ANDROID,
    ...GOOGLE_CLIENT_ID_WEB,
    ...GOOGLE_SERVER_CLIENT_ID,
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
  
  // Try to verify with each configured bundle ID (to support multiple apps)
  if (APPLE_BUNDLE_IDS.length > 0) {
    let lastError: Error | null = null;
    
    for (const bundleId of APPLE_BUNDLE_IDS) {
      try {
        const options: jose.JWTVerifyOptions = {
          issuer: 'https://appleid.apple.com',
          audience: bundleId,
        };
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
      } catch (err) {
        lastError = err as Error;
        // Continue to next bundle ID
      }
    }
    
    // If we get here, none of the bundle IDs worked
    throw lastError || new Error('Failed to verify Apple token with any configured bundle ID');
  } else {
    // No bundle IDs configured, verify without audience check
    const options: jose.JWTVerifyOptions = { issuer: 'https://appleid.apple.com' };
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
}

router.post('/google', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });
    const idToken = (req.body?.idToken ?? '') as string;
    if (!idToken) return res.status(400).json({ message: 'idToken is required' });
    const profile = await verifyGoogleIdToken(idToken);
    await upsertUser(profile);
    try {
      await ensureManagerDocument(profile);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[auth] ensureManagerDocument failed, proceeding with login', err);
    }
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
    try {
      await ensureManagerDocument(profile);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[auth] ensureManagerDocument failed, proceeding with login', err);
    }
    const token = issueAppJwt(profile);
    res.json({ token, user: profile });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Apple verification failed:', err);
    res.status(401).json({ message: 'Apple auth failed' });
  }
});

export default router;


