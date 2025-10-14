# Flutter Web Deployment Setup

This document explains how to configure GitHub Actions to automatically deploy your Flutter web app with Apple Sign In support.

## Prerequisites

1. Your web app will be deployed to `https://app.nexapymesoft.com`
2. Apple Sign In is configured with Service ID: `com.pymesoft.nexa.web`
3. Apple Redirect URI: `https://app.nexapymesoft.com/auth/callback`

## GitHub Repository Setup

### Step 1: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add the following **Secrets** (these contain sensitive data):

```
API_BASE_URL = https://api.nexapymesoft.com
API_PATH_PREFIX = /api
GOOGLE_CLIENT_ID_WEB = <your-google-web-client-id>
GOOGLE_SERVER_CLIENT_ID = <your-google-server-client-id>
APPLE_SERVICE_ID = com.pymesoft.nexa.web
APPLE_REDIRECT_URI = https://app.nexapymesoft.com/auth/callback
GOOGLE_MAPS_API_KEY = <your-google-maps-api-key>
OPENAI_API_KEY = <your-openai-api-key>
SERVER_SSH_KEY = <your-ssh-private-key-for-deployment>
```

### Step 2: Configure GitHub Variables

Go to your GitHub repository → Settings → Secrets and variables → Actions → Variables tab → New repository variable

Add the following **Variables** (these are non-sensitive config):

```
SERVER_HOST = <your-server-ip-or-domain>
SERVER_USER = <your-ssh-username>
OPENAI_BASE_URL = https://api.openai.com/v1
OPENAI_VISION_MODEL = gpt-4o-mini
OPENAI_TEXT_MODEL = gpt-4.1-mini
PLACES_BIAS_LAT = 39.7392
PLACES_BIAS_LNG = -104.9903
PLACES_COMPONENTS = country:us
```

## How It Works

1. **Trigger**: The workflow runs automatically when you push to the `main` branch (if files in `lib/`, `web/`, or `pubspec.yaml` change)

2. **Build**: Flutter builds the web app with all environment variables baked in using `--dart-define`

3. **Deploy**: The built files from `build/web/` are copied to your server at `/var/www/nexa-web`

4. **Serve**: Your web server (Caddy/Nginx) serves these files

## Apple Sign In Requirements

For Apple Sign In to work on the web:

### 1. Apple Services ID Configuration

In Apple Developer Console:
- Service ID: `com.pymesoft.nexa.web`
- Domain: `app.nexapymesoft.com`
- Return URLs: `https://app.nexapymesoft.com/auth/callback`

### 2. Web Server Configuration (Caddy)

Your Caddyfile should handle the SPA routing:

```caddyfile
app.nexapymesoft.com {
    root * /var/www/nexa-web
    encode gzip

    # Serve static files
    file_server

    # SPA fallback - all routes go to index.html
    try_files {path} /index.html

    # Handle auth callback
    @authCallback {
        path /auth/callback*
    }
    rewrite @authCallback /index.html
}
```

### 3. DNS Configuration

Ensure `app.nexapymesoft.com` points to your Linode server

## Testing Apple Sign In

### Local Testing

Test locally with all the same defines:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://api.nexapymesoft.com \
  --dart-define=API_PATH_PREFIX=/api \
  --dart-define=GOOGLE_CLIENT_ID_WEB=<your-google-web-client-id> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<your-google-server-client-id> \
  --dart-define=APPLE_SERVICE_ID=com.pymesoft.nexa.web \
  --dart-define=APPLE_REDIRECT_URI=https://app.nexapymesoft.com/auth/callback \
  --dart-define=GOOGLE_MAPS_API_KEY=<your-key>
```

**Note**: Local testing will redirect to production URL after Apple auth. For true local testing, create a separate Apple Service ID with `localhost:port` as the redirect URI.

### Production Testing

After deployment:

1. Navigate to `https://app.nexapymesoft.com`
2. Click "Continue with Apple"
3. Complete Apple authentication
4. You should be redirected back to your app at `/auth/callback`
5. The app handles the callback and completes sign-in

## Troubleshooting

### Apple Sign In button doesn't show

**Check**:
- Browser console for errors
- Environment variables are set in GitHub Secrets
- Apple Service ID and Redirect URI are correct
- The workflow ran successfully

**Debug**:
```javascript
// In browser console at app.nexapymesoft.com
console.log(window.flutter_config || 'No flutter_config found');
```

### Apple Sign In fails with redirect error

**Check**:
- Apple Developer Console has exact redirect URI: `https://app.nexapymesoft.com/auth/callback`
- No trailing slash differences
- Domain is verified in Apple Services ID

### Build fails in GitHub Actions

**Check**:
- All required secrets are set
- Flutter version in workflow matches your local version
- No syntax errors in workflow YAML

## Manual Deployment

If you need to build and deploy manually:

```bash
# Build
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.nexapymesoft.com \
  --dart-define=API_PATH_PREFIX=/api \
  --dart-define=GOOGLE_CLIENT_ID_WEB=<your-google-web-client-id> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<your-google-server-client-id> \
  --dart-define=APPLE_SERVICE_ID=com.pymesoft.nexa.web \
  --dart-define=APPLE_REDIRECT_URI=https://app.nexapymesoft.com/auth/callback \
  --dart-define=GOOGLE_MAPS_API_KEY=<your-key> \
  --dart-define=OPENAI_API_KEY=<your-key>

# Deploy
scp -r build/web/* user@server:/var/www/nexa-web/
ssh user@server 'sudo systemctl reload caddy'
```

## Next Steps

1. ✅ Configure all GitHub Secrets and Variables
2. ✅ Commit and push to `main` branch
3. ✅ Watch GitHub Actions workflow run
4. ✅ Test Apple Sign In at `https://app.nexapymesoft.com`
5. ✅ Monitor logs for any issues

## Support

If Apple Sign In still doesn't work:
1. Check GitHub Actions logs
2. Check browser console for JavaScript errors
3. Verify Apple Developer Console configuration
4. Check server logs for redirect handling
