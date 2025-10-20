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
const APPLE_SERVICE_IDS = ENV.appleServiceId;
const APPLE_AUDIENCE_IDS = Array.from(new Set([...APPLE_BUNDLE_IDS, ...APPLE_SERVICE_IDS]));
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
if (APPLE_AUDIENCE_IDS.length === 0) {
  // eslint-disable-next-line no-console
  console.warn(
    '[auth] No Apple audience configured. Set APPLE_BUNDLE_ID and/or APPLE_SERVICE_ID.',
  );
}

function issueAppJwt(profile: VerifiedProfile, managerId?: string): string {
  const payload = {
    sub: profile.subject,
    provider: profile.provider,
    email: profile.email,
    name: profile.name,
    picture: profile.picture,
    ...(managerId && { managerId }),
  } as const;
  return jwt.sign(payload, JWT_SECRET, { algorithm: 'HS256', expiresIn: '7d' });
}

async function upsertUser(profile: VerifiedProfile) {
  const filter = { provider: profile.provider, subject: profile.subject } as const;

  // Try to intelligently split the OAuth name into first and last name for new users
  let firstName: string | undefined;
  let lastName: string | undefined;
  if (profile.name) {
    const nameParts = profile.name.trim().split(/\s+/);
    if (nameParts.length > 0) {
      firstName = nameParts[0];
      if (nameParts.length > 1) {
        lastName = nameParts.slice(1).join(' ');
      }
    }
  }

  const update = {
    $set: {
      // Always update these OAuth fields on every login
      email: profile.email,
      name: profile.name,
      picture: profile.picture,
      updatedAt: new Date(),
    },
    $setOnInsert: {
      // Only set these on user creation - preserve custom fields on subsequent logins
      provider: profile.provider,
      subject: profile.subject,
      createdAt: new Date(),
      // Pre-populate first and last name from OAuth if available (only on creation)
      ...(firstName && { first_name: firstName }),
      ...(lastName && { last_name: lastName }),
    },
  } as const;
  await UserModel.updateOne(filter, update, { upsert: true });
}

async function ensureManagerDocument(profile: VerifiedProfile) {
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
  await ManagerModel.updateOne(filter, update, { upsert: true });
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

  // Try to verify with each configured audience (bundle IDs or web service IDs)
  if (APPLE_AUDIENCE_IDS.length > 0) {
    let lastError: Error | null = null;

    for (const audience of APPLE_AUDIENCE_IDS) {
      try {
        const options: jose.JWTVerifyOptions = {
          issuer: 'https://appleid.apple.com',
          audience,
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
        // Continue to next configured audience value
      }
    }

    // If we get here, none of the configured audience values worked
    throw lastError || new Error('Failed to verify Apple token with any configured audience');
  } else {
    // No audience configured, verify without audience check
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

async function verifyGoogleAccessToken(accessToken: string): Promise<VerifiedProfile> {
  // Fetch user info from Google using the access token
  const response = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch user info: ${response.statusText}`);
  }

  const data = await response.json();

  if (!data.id) {
    throw new Error('Invalid Google access token - no user ID');
  }

  return {
    provider: 'google',
    subject: data.id,
    email: data.email ?? undefined,
    name: data.name ?? undefined,
    picture: data.picture ?? undefined,
  };
}

router.post('/google', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });

    const idToken = (req.body?.idToken ?? '') as string;
    const accessToken = (req.body?.accessToken ?? '') as string;

    if (!idToken && !accessToken) {
      return res.status(400).json({ message: 'idToken or accessToken is required' });
    }

    // Prefer idToken, fall back to accessToken
    let profile: VerifiedProfile;
    if (idToken) {
      profile = await verifyGoogleIdToken(idToken);
    } else {
      profile = await verifyGoogleAccessToken(accessToken);
    }

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

// Manager-specific auth endpoints that include managerId in JWT
router.post('/manager/google', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });

    const idToken = (req.body?.idToken ?? '') as string;
    const accessToken = (req.body?.accessToken ?? '') as string;

    if (!idToken && !accessToken) {
      return res.status(400).json({ message: 'idToken or accessToken is required' });
    }

    // Prefer idToken, fall back to accessToken
    let profile: VerifiedProfile;
    if (idToken) {
      profile = await verifyGoogleIdToken(idToken);
    } else {
      profile = await verifyGoogleAccessToken(accessToken);
    }

    // Ensure manager document exists and get managerId
    await ensureManagerDocument(profile);
    const manager = await ManagerModel.findOne({
      provider: profile.provider,
      subject: profile.subject,
    });

    if (!manager) {
      return res.status(500).json({ message: 'Failed to create manager profile' });
    }

    const token = issueAppJwt(profile, String(manager._id));
    res.json({ token, user: profile });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Manager Google verification failed:', err);
    res.status(401).json({ message: 'Google auth failed' });
  }
});

router.post('/manager/apple', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });
    const identityToken = (req.body?.identityToken ?? '') as string;
    if (!identityToken) return res.status(400).json({ message: 'identityToken is required' });

    const profile = await verifyAppleIdentityToken(identityToken);

    // Ensure manager document exists and get managerId
    await ensureManagerDocument(profile);
    const manager = await ManagerModel.findOne({
      provider: profile.provider,
      subject: profile.subject,
    });

    if (!manager) {
      return res.status(500).json({ message: 'Failed to create manager profile' });
    }

    const token = issueAppJwt(profile, String(manager._id));
    res.json({ token, user: profile });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Manager Apple verification failed:', err);
    res.status(401).json({ message: 'Apple auth failed' });
  }
});

export default router;
