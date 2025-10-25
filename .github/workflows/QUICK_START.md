# Flutter Web CI/CD - Quick Start

This is a condensed setup guide. For complete documentation, see [FLUTTER_WEB_CI_CD_SETUP.md](./FLUTTER_WEB_CI_CD_SETUP.md).

## 5-Minute Setup

### Step 1: Add GitHub Secrets

1. Go to GitHub repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add:

```
Name: CLOUDFLARE_API_TOKEN
Value: [Your Cloudflare API token]

Name: CLOUDFLARE_ACCOUNT_ID
Value: [Your Cloudflare account ID]
```

**How to get these values:**
- **API Token**: Cloudflare Dashboard → Profile → API Tokens → Create Token
  - Use "Edit Cloudflare Workers" template
  - Permissions: Account > Cloudflare Pages > Edit
- **Account ID**: Cloudflare Dashboard → Pages (shown in right sidebar)

### Step 2: Verify Cloudflare Project

Ensure you have a Cloudflare Pages project named **`nexa-web`**.

- If different name: Edit line 147 in `.github/workflows/flutter-web-deploy.yml`
- If no project exists: First deployment will create it automatically

### Step 3: Push Changes

```bash
git add .github/workflows/flutter-web-deploy.yml
git commit -m "Add Flutter web CI/CD pipeline"
git push origin android1
```

### Step 4: Watch It Run

1. Go to GitHub → **Actions** tab
2. Click on the running workflow
3. Monitor each job's progress

## What Happens When You Push

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ANALYZE & TEST (Fail Fast)                               │
│    ✓ flutter analyze (catches errors)                       │
│    ✓ flutter test (validates logic)                         │
│    ↓ If anything fails, STOP HERE                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. BUILD WEB                                                 │
│    ✓ flutter build web --release                            │
│    ✓ Verify build/web/index.html exists                     │
│    ↓ If build fails, STOP HERE                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. DEPLOY TO CLOUDFLARE                                      │
│    ✓ Download build artifacts                               │
│    ✓ Deploy to Cloudflare Pages                             │
│    ✓ Deployment successful!                                 │
└─────────────────────────────────────────────────────────────┘
```

## Workflow Triggers

| Event | Trigger | Result |
|-------|---------|--------|
| Push to `main` or `android1` | Changes to Flutter files | Deploy to production |
| Pull request to `main` | Changes to Flutter files | Deploy preview |
| Push to other branches | Changes to Flutter files | Analyze + Build only |
| Manual trigger | Any branch | Run full pipeline |

## Common Issues & Quick Fixes

### ❌ "flutter analyze failed"

```bash
# Run locally to see errors
flutter analyze

# Fix errors and push
git add .
git commit -m "fix: resolve analyzer errors"
git push
```

### ❌ "flutter test failed"

```bash
# Run locally to see which tests fail
flutter test

# Fix tests and push
git add .
git commit -m "fix: update failing tests"
git push
```

### ❌ "Cloudflare authentication failed"

1. Verify secrets are set: GitHub → Settings → Secrets
2. Re-create API token in Cloudflare Dashboard
3. Update `CLOUDFLARE_API_TOKEN` secret
4. Re-run workflow: Actions → Re-run jobs

### ❌ "Build output not found"

```bash
# Test build locally
flutter build web --release

# Check output
ls -la build/web/index.html

# If it works locally but fails in CI, check pubspec.yaml
```

## Testing Before You Push

**Prevent pipeline failures by running these locally:**

```bash
# 1. Analyze code
flutter analyze
# Should show: No issues found!

# 2. Run tests
flutter test
# Should show: All tests passed!

# 3. Build for web
flutter build web --release
# Should show: ✓ Built build/web

# 4. If all pass, push safely
git push origin android1
```

## Environment Variables

The workflow builds without environment variables. Add them in **Cloudflare Pages Dashboard**:

1. Go to Cloudflare Pages → **nexa-web** → **Settings** → **Environment variables**
2. Add for **Production**:

```bash
API_BASE_URL=https://api.nexapymesoft.com
API_PATH_PREFIX=/api
GOOGLE_CLIENT_ID_WEB=your-google-client-id
GOOGLE_SERVER_CLIENT_ID=your-server-client-id
APPLE_SERVICE_ID=com.pymesoft.nexa.web
APPLE_REDIRECT_URI=https://app.nexapymesoft.com/auth/callback
```

## Manual Deployment (Emergency)

If GitHub Actions is down or you need to deploy immediately:

```bash
# Install Wrangler
npm install -g wrangler

# Login to Cloudflare
wrangler login

# Build Flutter web
flutter build web --release

# Deploy
wrangler pages deploy build/web --project-name=nexa-web
```

## Rollback

If a deployment breaks production:

1. Go to Cloudflare Pages → **nexa-web** → **Deployments**
2. Find last working deployment
3. Click **...** → **Rollback to this deployment**

## Monitoring

### Check Pipeline Status
- GitHub repository → **Actions** tab
- Green checkmarks = success
- Red X = failure (click for logs)

### Check Deployment Status
- Cloudflare Dashboard → **Pages** → **nexa-web** → **Deployments**
- Shows all deployments with timestamps

### Check Live Site
- Production: `https://app.nexapymesoft.com`
- Preview (PRs): `https://[branch-name].nexa-web.pages.dev`

## Key Features

1. **Fail Fast**: Errors caught before deployment
2. **Preview Deployments**: Test PRs before merging
3. **Automatic Testing**: Every push runs tests
4. **Build Caching**: Faster subsequent builds
5. **Artifact Storage**: Build outputs saved for 3 days
6. **Rollback Support**: Easy recovery from bad deployments

## Files Created

```
.github/workflows/
├── flutter-web-deploy.yml          # Main workflow
├── FLUTTER_WEB_CI_CD_SETUP.md      # Complete documentation
└── QUICK_START.md                  # This file
```

## Next Steps

1. ✅ Add GitHub Secrets
2. ✅ Verify Cloudflare project exists
3. ✅ Push workflow to trigger first deployment
4. 📖 Read [FLUTTER_WEB_CI_CD_SETUP.md](./FLUTTER_WEB_CI_CD_SETUP.md) for advanced configuration
5. 🎉 Enjoy automated deployments!

## Need Help?

- **Full documentation**: [FLUTTER_WEB_CI_CD_SETUP.md](./FLUTTER_WEB_CI_CD_SETUP.md)
- **Cloudflare docs**: https://developers.cloudflare.com/pages/
- **Flutter web docs**: https://docs.flutter.dev/platform-integration/web
- **GitHub Actions docs**: https://docs.github.com/en/actions

---

**Created**: October 24, 2025
**Workflow Version**: 1.0.0
**Status**: Ready for production ✅
