# Apple Sign In Debugging Guide

## Current Error
```
API 401: {"message":"Apple auth failed"}
```

This error means your backend received the Apple identity token but **rejected it during verification**.

## What's Happening

1. ✅ **Frontend (Cloudflare Pages)** - Working correctly
   - Apple Sign In button is visible
   - User clicks "Continue with Apple"
   - Apple popup appears and user authenticates
   - Apple returns an identity token
   - Flutter app sends token to backend

2. ❌ **Backend (api.nexapymesoft.com)** - Rejecting the token
   - Backend receives the identity token
   - Backend tries to verify it against configured audience
   - Verification fails → Returns 401 error

## Root Cause

The backend is rejecting the token because it's **not configured to accept `com.pymesoft.nexa.web` as a valid audience**.

## Step-by-Step Fix

### 1. Verify Backend Environment Variables

SSH into your backend server and check the environment variables:

```bash
# SSH into your backend server
ssh user@your-server

# Navigate to backend directory
cd /path/to/backend

# Check environment variables
cat .env | grep APPLE
```

**Expected output:**
```
APPLE_BUNDLE_ID=com.pymesoft.nexa
APPLE_SERVICE_ID=com.pymesoft.nexa.web
```

**If `APPLE_SERVICE_ID` is missing or incorrect:**
```bash
# Edit the .env file
nano .env

# Add or update this line:
APPLE_SERVICE_ID=com.pymesoft.nexa.web

# Save and exit (Ctrl+X, then Y, then Enter)
```

### 2. Check Backend Startup Logs

The backend logs a warning at startup if Apple configuration is missing:

```bash
# View logs (adjust command based on your setup)

# If using PM2:
pm2 logs

# If using systemd:
journalctl -u your-backend-service -n 100

# If using Docker:
docker logs your-container-name

# If running directly:
tail -f /var/log/your-backend.log
```

**Look for this at startup:**
```
[auth] No Apple audience configured. Set APPLE_BUNDLE_ID and/or APPLE_SERVICE_ID.
```

**If you see this warning:** The environment variables aren't being loaded properly.

**Should see instead:**
```
Server running on port 4000
(No warning about Apple configuration)
```

### 3. Restart Backend Service

After updating `.env`, restart the backend:

```bash
# If using PM2:
pm2 restart all

# If using systemd:
sudo systemctl restart your-backend-service

# If using Docker:
docker restart your-container-name

# If running directly with npm:
cd /path/to/backend
npm run build
npm start
```

### 4. Test Again

1. Go to `https://app.nexapymesoft.com`
2. Clear browser cache (Cmd+Shift+R or Ctrl+Shift+R)
3. Click "Continue with Apple"
4. Complete Apple authentication

**If it still fails:**
- Check backend logs immediately after the failed attempt
- Look for: `[auth] Apple verification failed: <error details>`
- This will tell you the exact reason

### 5. Common Deployment Platform Issues

#### If deployed on **Linode/VPS**:
```bash
# Make sure .env file exists in the right location
ls -la /path/to/backend/.env

# Check file permissions
chmod 600 /path/to/backend/.env

# Verify the process is loading it
ps aux | grep node
```

#### If deployed on **Heroku**:
```bash
# Set environment variables via CLI
heroku config:set APPLE_SERVICE_ID=com.pymesoft.nexa.web

# Verify
heroku config | grep APPLE
```

#### If deployed on **Railway**:
- Go to Railway dashboard → Your project → Variables
- Add: `APPLE_SERVICE_ID` = `com.pymesoft.nexa.web`
- Redeploy

#### If deployed on **Render**:
- Go to Render dashboard → Your service → Environment
- Add: `APPLE_SERVICE_ID` = `com.pymesoft.nexa.web`
- Click "Save Changes" (auto-redeploys)

## Advanced Debugging

### Check what the backend actually receives

Add temporary logging to your backend:

Edit `backend/src/routes/auth.ts` around line 239:

```typescript
router.post('/apple', async (req, res) => {
  try {
    if (!JWT_SECRET) return res.status(500).json({ message: 'Server missing JWT secret' });
    const identityToken = (req.body?.identityToken ?? '') as string;
    if (!identityToken) return res.status(400).json({ message: 'identityToken is required' });

    // TEMPORARY DEBUG LOGGING
    console.log('[DEBUG] Apple audience IDs configured:', APPLE_AUDIENCE_IDS);
    console.log('[DEBUG] Received identity token (first 50 chars):', identityToken.substring(0, 50));

    const profile = await verifyAppleIdentityToken(identityToken);
    // ... rest of code
```

Then check logs after attempting sign-in.

### Decode the identity token manually

The identity token is a JWT. You can decode it to see what Apple sent:

1. Copy the identity token from browser console (if you log it)
2. Go to https://jwt.io
3. Paste the token
4. Check the **Payload** section
5. Look for the `aud` field - it should be `com.pymesoft.nexa.web`

If `aud` is something else, you may have misconfigured the Apple Services ID in Apple Developer Console.

## Apple Developer Console Verification

1. Go to https://developer.apple.com
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → Find your Services ID (`com.pymesoft.nexa.web`)
4. Click **Configure** next to "Sign In with Apple"
5. Verify:
   - **Domains**: `app.nexapymesoft.com`
   - **Return URLs**: `https://app.nexapymesoft.com/auth/callback`
   - Click **Done** and **Save**

## Final Checklist

- [ ] Backend `.env` has `APPLE_SERVICE_ID=com.pymesoft.nexa.web`
- [ ] Backend has been restarted after updating `.env`
- [ ] Backend startup logs don't show Apple configuration warning
- [ ] Apple Developer Console has correct domain and return URL
- [ ] Cloudflare Pages has `APPLE_SERVICE_ID` environment variable set
- [ ] Latest deployment includes the updated `build.sh` script
- [ ] Browser cache has been cleared

## Still Not Working?

If you've verified all of the above and it still doesn't work, **share your backend logs** showing:
1. Startup logs (to confirm env vars are loaded)
2. Logs from a failed Apple sign-in attempt (showing the exact error)

The error message will reveal exactly what's wrong.
