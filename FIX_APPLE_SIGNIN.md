# How to Fix "Apple auth failed" Error

## Quick Summary

Your Apple Sign In is failing with `API 401: {"message":"Apple auth failed"}` because your **backend server** doesn't have `APPLE_SERVICE_ID` configured.

## 3-Step Fix

### Step 1: Update Backend Environment Variables

SSH into your backend server where `api.nexapymesoft.com` is hosted:

```bash
# 1. SSH into your server
ssh your-user@your-server-ip

# 2. Navigate to backend directory
cd /path/to/nexa/backend

# 3. Edit .env file
nano .env
```

Add or update this line in your `.env` file:

```bash
APPLE_SERVICE_ID=com.pymesoft.nexa.web
```

Your `.env` should now include (at minimum):

```bash
PORT=4000
MONGO_URI=mongodb+srv://...your-connection-string...
BACKEND_JWT_SECRET=your-secure-random-secret
APPLE_BUNDLE_ID=com.pymesoft.nexa
APPLE_SERVICE_ID=com.pymesoft.nexa.web
GOOGLE_CLIENT_ID_WEB=your-google-web-client-id
GOOGLE_SERVER_CLIENT_ID=your-google-server-client-id
```

Save and exit (Ctrl+X, then Y, then Enter).

### Step 2: Verify Configuration (Optional but Recommended)

Run the diagnostic script:

```bash
# Copy backend_env_check.js to your server, then run:
node backend_env_check.js
```

This will tell you exactly what's configured and what's missing.

### Step 3: Restart Backend Server

```bash
# If using PM2:
pm2 restart all

# If using systemd:
sudo systemctl restart your-backend-service

# If using Docker:
docker restart your-backend-container

# If running with npm:
npm run build && npm start
```

## Verify the Fix

After restarting:

1. Check backend logs to confirm no warnings:
   ```bash
   # Look for this line - you should NOT see it anymore:
   [auth] No Apple audience configured...
   ```

2. Go to `https://app.nexapymesoft.com`

3. Clear browser cache: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)

4. Click "Continue with Apple"

5. Complete Apple authentication

6. ✅ Should now work!

## Why This Happens

- **Web Sign In** uses Service ID: `com.pymesoft.nexa.web`
- **iOS App** uses Bundle ID: `com.pymesoft.nexa`

Your backend needs to know **both** to verify tokens from both platforms.

The backend code at `backend/src/routes/auth.ts:123-156` tries to verify the Apple token against **all configured audience IDs**:

```typescript
const APPLE_AUDIENCE_IDS = Array.from(new Set([...APPLE_BUNDLE_IDS, ...APPLE_SERVICE_IDS]));
```

If `APPLE_SERVICE_ID` is not set, this array only contains the bundle ID, so **web tokens are rejected**.

## Still Not Working?

### Check Backend Logs

After attempting sign-in, check logs for the exact error:

```bash
# The backend logs this when Apple verification fails:
[auth] Apple verification failed: <error details>
```

Common errors:

1. **"Invalid audience"** → `APPLE_SERVICE_ID` not set or wrong value
2. **"Invalid issuer"** → Apple configuration issue (rare)
3. **"Invalid signature"** → Network/SSL issue (rare)

### Check Apple Developer Console

1. Go to https://developer.apple.com
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. Find Services ID: `com.pymesoft.nexa.web`
4. Click **Configure** next to "Sign In with Apple"
5. Verify:
   - **Domains**: `app.nexapymesoft.com` ✅
   - **Return URLs**: `https://app.nexapymesoft.com/auth/callback` ✅
6. Save if you made changes

### Deployment Platform Specific

If your backend is deployed on a platform (not a VPS):

**Heroku:**
```bash
heroku config:set APPLE_SERVICE_ID=com.pymesoft.nexa.web -a your-app-name
```

**Railway:**
- Dashboard → Your Project → Variables → Add Variable
- Key: `APPLE_SERVICE_ID`
- Value: `com.pymesoft.nexa.web`

**Render:**
- Dashboard → Your Service → Environment → Add Environment Variable
- Key: `APPLE_SERVICE_ID`
- Value: `com.pymesoft.nexa.web`

## Need More Help?

Run the diagnostic script and share the output:

```bash
node backend_env_check.js
```

This will show exactly what's configured and what's missing.
