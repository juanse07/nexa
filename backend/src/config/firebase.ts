import * as admin from 'firebase-admin';
import { ENV } from './env';

// Initialize Firebase Admin SDK only if credentials are provided
let firebaseAuth: admin.auth.Auth | null = null;

if (ENV.firebaseProjectId && ENV.firebaseClientEmail && ENV.firebasePrivateKey) {
  try {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: ENV.firebaseProjectId,
          clientEmail: ENV.firebaseClientEmail,
          // Handle escaped newlines in the private key
          privateKey: ENV.firebasePrivateKey.replace(/\\n/g, '\n'),
        }),
      });
    }
    firebaseAuth = admin.auth();
    // eslint-disable-next-line no-console
    console.log('[firebase] Firebase Admin SDK initialized successfully');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('[firebase] Failed to initialize Firebase Admin SDK:', err);
  }
} else {
  // eslint-disable-next-line no-console
  console.warn(
    '[firebase] Firebase credentials not configured. Phone auth will not work.',
    'Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY in .env'
  );
}

export { firebaseAuth };
export default admin;
