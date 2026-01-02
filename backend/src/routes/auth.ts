import { Router } from 'express';
import { OAuth2Client } from 'google-auth-library';
import * as jose from 'jose';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env';
import { firebaseAuth } from '../config/firebase';
import { UserModel } from '../models/user';
import { ManagerModel } from '../models/manager';
import { requireAuth, AuthenticatedUser } from '../middleware/requireAuth';

type VerifiedProfile = {
  provider: 'google' | 'apple' | 'phone';
  subject: string;
  email?: string | undefined;
  name?: string | undefined;
  picture?: string | undefined;
  phoneNumber?: string | undefined;
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
    phoneNumber: profile.phoneNumber,
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

// ============================================================================
// PHONE AUTHENTICATION ENDPOINTS
// ============================================================================

async function verifyFirebasePhoneToken(firebaseIdToken: string): Promise<VerifiedProfile> {
  if (!firebaseAuth) {
    throw new Error('Firebase Admin SDK not initialized. Check FIREBASE_* environment variables.');
  }

  const decodedToken = await firebaseAuth.verifyIdToken(firebaseIdToken);

  if (!decodedToken.phone_number) {
    throw new Error('Firebase token does not contain a phone number');
  }

  return {
    provider: 'phone',
    subject: decodedToken.uid, // Firebase UID
    phoneNumber: decodedToken.phone_number,
    email: undefined,
    name: undefined,
    picture: undefined,
  };
}

// Staff phone authentication
router.post('/phone', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });

    const firebaseIdToken = (req.body?.firebaseIdToken ?? '') as string;
    if (!firebaseIdToken) {
      return res.status(400).json({ message: 'firebaseIdToken is required' });
    }

    const profile = await verifyFirebasePhoneToken(firebaseIdToken);

    // Check if user exists by phone number OR by provider+subject
    let user = await UserModel.findOne({
      $or: [
        { provider: 'phone', subject: profile.subject },
        { auth_phone_number: profile.phoneNumber },
      ],
    });

    if (!user) {
      // Create new user with phone as primary auth
      user = await UserModel.create({
        provider: 'phone',
        subject: profile.subject,
        auth_phone_number: profile.phoneNumber,
        phone_number: profile.phoneNumber, // Also set as profile phone
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    } else {
      // User exists - update auth_phone_number if not set
      if (!user.auth_phone_number) {
        user.auth_phone_number = profile.phoneNumber;
        await user.save();
      }
    }

    // Issue JWT using the user's original provider/subject (for linked accounts)
    const token = issueAppJwt({
      provider: user.provider,
      subject: user.subject,
      email: user.email,
      name: user.name,
      picture: user.picture,
      phoneNumber: profile.phoneNumber,
    });

    res.json({ token, user: profile });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Phone verification failed:', err);
    const message = (err as Error).message || 'Phone auth failed';
    res.status(401).json({ message });
  }
});

// Manager phone authentication
router.post('/manager/phone', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });

    const firebaseIdToken = (req.body?.firebaseIdToken ?? '') as string;
    if (!firebaseIdToken) {
      return res.status(400).json({ message: 'firebaseIdToken is required' });
    }

    const profile = await verifyFirebasePhoneToken(firebaseIdToken);

    // Check if manager exists by phone number OR by provider+subject
    let manager = await ManagerModel.findOne({
      $or: [
        { provider: 'phone', subject: profile.subject },
        { auth_phone_number: profile.phoneNumber },
      ],
    });

    if (!manager) {
      // Create new manager with phone as primary auth
      manager = await ManagerModel.create({
        provider: 'phone',
        subject: profile.subject,
        auth_phone_number: profile.phoneNumber,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    } else {
      // Manager exists - update auth_phone_number if not set
      if (!manager.auth_phone_number) {
        manager.auth_phone_number = profile.phoneNumber;
        await manager.save();
      }
    }

    // Issue JWT with managerId
    const token = issueAppJwt(
      {
        provider: manager.provider,
        subject: manager.subject,
        email: manager.email,
        name: manager.name,
        picture: manager.picture,
        phoneNumber: profile.phoneNumber,
      },
      String(manager._id)
    );

    res.json({ token, user: profile });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Manager phone verification failed:', err);
    const message = (err as Error).message || 'Phone auth failed';
    res.status(401).json({ message });
  }
});

// Link phone number to existing account (requires authentication)
router.post('/link-phone', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser as AuthenticatedUser;
    const firebaseIdToken = (req.body?.firebaseIdToken ?? '') as string;

    if (!firebaseIdToken) {
      return res.status(400).json({ message: 'firebaseIdToken is required' });
    }

    const phoneProfile = await verifyFirebasePhoneToken(firebaseIdToken);

    // Check if this phone is already linked to another account
    const existingUser = await UserModel.findOne({
      auth_phone_number: phoneProfile.phoneNumber,
      $or: [{ provider: { $ne: authUser.provider } }, { subject: { $ne: authUser.sub } }],
    });

    if (existingUser) {
      return res.status(409).json({
        message: 'This phone number is already linked to another account',
      });
    }

    // Link phone to current user
    const updated = await UserModel.findOneAndUpdate(
      { provider: authUser.provider, subject: authUser.sub },
      {
        $set: {
          auth_phone_number: phoneProfile.phoneNumber,
          updatedAt: new Date(),
        },
        $addToSet: {
          linked_providers: {
            provider: 'phone',
            subject: phoneProfile.subject,
            linked_at: new Date(),
          },
        },
      },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({
      success: true,
      message: 'Phone number linked successfully',
      phoneNumber: phoneProfile.phoneNumber,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Link phone failed:', err);
    const message = (err as Error).message || 'Failed to link phone number';
    res.status(500).json({ message });
  }
});

// Unlink phone number from account (requires authentication)
router.post('/unlink-phone', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser as AuthenticatedUser;

    const user = await UserModel.findOne({
      provider: authUser.provider,
      subject: authUser.sub,
    });

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Cannot unlink if phone is the primary auth method
    if (user.provider === 'phone') {
      return res.status(400).json({
        message: 'Cannot unlink phone - it is your primary login method',
      });
    }

    await UserModel.updateOne(
      { _id: user._id },
      {
        $unset: { auth_phone_number: 1 },
        $pull: { linked_providers: { provider: 'phone' } },
        $set: { updatedAt: new Date() },
      }
    );

    res.json({ success: true, message: 'Phone number unlinked' });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Unlink phone failed:', err);
    res.status(500).json({ message: 'Failed to unlink phone number' });
  }
});

// Manager link phone
router.post('/manager/link-phone', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser as AuthenticatedUser;
    const firebaseIdToken = (req.body?.firebaseIdToken ?? '') as string;

    if (!authUser.managerId) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    if (!firebaseIdToken) {
      return res.status(400).json({ message: 'firebaseIdToken is required' });
    }

    const phoneProfile = await verifyFirebasePhoneToken(firebaseIdToken);

    // Check if this phone is already linked to another manager
    const existingManager = await ManagerModel.findOne({
      auth_phone_number: phoneProfile.phoneNumber,
      _id: { $ne: authUser.managerId },
    });

    if (existingManager) {
      return res.status(409).json({
        message: 'This phone number is already linked to another account',
      });
    }

    // Link phone to current manager
    const updated = await ManagerModel.findByIdAndUpdate(
      authUser.managerId,
      {
        $set: {
          auth_phone_number: phoneProfile.phoneNumber,
          updatedAt: new Date(),
        },
        $addToSet: {
          linked_providers: {
            provider: 'phone',
            subject: phoneProfile.subject,
            linked_at: new Date(),
          },
        },
      },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: 'Manager not found' });
    }

    res.json({
      success: true,
      message: 'Phone number linked successfully',
      phoneNumber: phoneProfile.phoneNumber,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Manager link phone failed:', err);
    const message = (err as Error).message || 'Failed to link phone number';
    res.status(500).json({ message });
  }
});

// Manager unlink phone
router.post('/manager/unlink-phone', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser as AuthenticatedUser;

    if (!authUser.managerId) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const manager = await ManagerModel.findById(authUser.managerId);

    if (!manager) {
      return res.status(404).json({ message: 'Manager not found' });
    }

    // Cannot unlink if phone is the primary auth method
    if (manager.provider === 'phone') {
      return res.status(400).json({
        message: 'Cannot unlink phone - it is your primary login method',
      });
    }

    await ManagerModel.updateOne(
      { _id: manager._id },
      {
        $unset: { auth_phone_number: 1 },
        $pull: { linked_providers: { provider: 'phone' } },
        $set: { updatedAt: new Date() },
      }
    );

    res.json({ success: true, message: 'Phone number unlinked' });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[auth] Manager unlink phone failed:', err);
    res.status(500).json({ message: 'Failed to unlink phone number' });
  }
});

export default router;
