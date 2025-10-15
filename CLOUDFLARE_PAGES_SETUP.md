# Cloudflare Pages Setup for Apple Sign In

> **Last Updated**: October 14, 2025

## Step 1: Configure Environment Variables

Go to: **Cloudflare Dashboard** → **Pages** → **nexa-web** → **Settings** → **Environment variables**

Add these environment variables for **Production**:

### Required for Apple Sign In:
```
APPLE_SERVICE_ID = com.pymesoft.nexa.web
APPLE_REDIRECT_URI = https://app.nexapymesoft.com/auth/callback
```

### Required for Google Sign In:
```
GOOGLE_CLIENT_ID_WEB = <your-google-web-client-id>
GOOGLE_SERVER_CLIENT_ID = <your-google-server-client-id>
```

### Required for API:
```
API_BASE_URL = https://api.nexapymesoft.com
API_PATH_PREFIX = /api
```

### Optional (if you use these features):
```
GOOGLE_MAPS_API_KEY = <your-google-maps-api-key>
OPENAI_API_KEY = <your-openai-api-key>
OPENAI_BASE_URL = https://api.openai.com/v1
OPENAI_VISION_MODEL = gpt-4o-mini
OPENAI_TEXT_MODEL = gpt-4.1-mini
PLACES_BIAS_LAT = 39.7392
PLACES_BIAS_LNG = -104.9903
PLACES_COMPONENTS = country:us
```

## Step 2: Update Build Configuration

Go to: **Cloudflare Dashboard** → **Pages** → **nexa-web** → **Settings** → **Builds & deployments**

### Build command:
```bash
flutter build web --release \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=API_PATH_PREFIX=$API_PATH_PREFIX \
  --dart-define=GOOGLE_CLIENT_ID_WEB=$GOOGLE_CLIENT_ID_WEB \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID \
  --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI \
  --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY \
  --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY \
  --dart-define=OPENAI_BASE_URL=$OPENAI_BASE_URL \
  --dart-define=OPENAI_VISION_MODEL=$OPENAI_VISION_MODEL \
  --dart-define=OPENAI_TEXT_MODEL=$OPENAI_TEXT_MODEL \
  --dart-define=PLACES_BIAS_LAT=$PLACES_BIAS_LAT \
  --dart-define=PLACES_BIAS_LNG=$PLACES_BIAS_LNG \
  --dart-define=PLACES_COMPONENTS=$PLACES_COMPONENTS
```

### Build output directory:
```
build/web
```

### Root directory:
```
/
```

## Step 3: Trigger a New Deployment

After saving the environment variables and build configuration:

1. Go to **Deployments** tab
2. Click **"Retry deployment"** on the latest deployment

   OR

3. Push a new commit to trigger automatic deployment:
   ```bash
   git commit --allow-empty -m "Trigger Cloudflare deployment with Apple Sign In"
   git push origin android1
   ```

## Step 4: Verify Apple Sign In

Once the deployment completes:

1. Go to `https://app.nexapymesoft.com`
2. Clear your browser cache (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows)
3. You should see the **"Continue with Apple"** button below Google Sign In
4. Click it to test the Apple Sign In flow

## Troubleshooting

### Apple button still doesn't show
- Check browser console for errors (F12 → Console)
- Verify environment variables are set in Cloudflare Pages
- Check that the build command includes all `--dart-define` flags
- Clear browser cache and hard reload

### Apple Sign In fails
- Verify Apple Services ID configuration in Apple Developer Console
- Ensure redirect URI is exactly: `https://app.nexapymesoft.com/auth/callback`
- Check that domain is verified in Apple Services ID

### Build fails in Cloudflare
- Check build logs in Cloudflare Pages → Deployments
- Verify Flutter version is compatible (3.9.0+)
- Ensure all environment variables are non-empty

## Notes

- Environment variables in Cloudflare Pages are available as `$VAR_NAME` in build commands
- You must use `--dart-define` flags to pass them to Flutter web builds
- Changes to environment variables require a new deployment to take effect
- The Apple Sign In button only shows on web when both `APPLE_SERVICE_ID` and `APPLE_REDIRECT_URI` are set
