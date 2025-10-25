# Flutter Web CI/CD Setup Checklist

Use this checklist to verify your CI/CD pipeline is configured correctly.

## Pre-Deployment Checklist

### 1. GitHub Repository Configuration

- [ ] Repository exists on GitHub
- [ ] You have admin/write access to repository
- [ ] `.github/workflows/flutter-web-deploy.yml` file is committed
- [ ] Workflow file is on `main` or `android1` branch

### 2. GitHub Secrets Configuration

Navigate to: **GitHub Repository** → **Settings** → **Secrets and variables** → **Actions**

- [ ] `CLOUDFLARE_API_TOKEN` is added
- [ ] `CLOUDFLARE_ACCOUNT_ID` is added
- [ ] Both secrets show "Updated [date]" (not empty)

**To verify secrets exist:**
```bash
# You should see both secrets listed with "Set" status
# (actual values are hidden for security)
```

### 3. Cloudflare Account Setup

- [ ] You have a Cloudflare account
- [ ] Account is verified and active
- [ ] You know your Cloudflare Account ID

**To find Account ID:**
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Click **Pages** in left sidebar
3. Account ID shown on right sidebar
4. OR: Click any domain → API section → Account ID

### 4. Cloudflare API Token Setup

- [ ] API token created in Cloudflare Dashboard
- [ ] Token has "Edit Cloudflare Workers" permissions OR custom with:
  - [ ] Account > Cloudflare Pages > Edit
- [ ] Token is not expired
- [ ] Token is saved in GitHub Secrets as `CLOUDFLARE_API_TOKEN`

**To create new token:**
1. Cloudflare Dashboard → Profile icon → **API Tokens**
2. Click **Create Token**
3. Use **"Edit Cloudflare Workers"** template
4. OR create custom with permissions listed above
5. Copy token immediately (won't be shown again!)

### 5. Cloudflare Pages Project

- [ ] Project named `nexa-web` exists in Cloudflare Pages
- [ ] OR: Different project name noted (update workflow line 147)
- [ ] OR: Understood that first deployment will create it

**To verify project exists:**
1. Go to [Cloudflare Pages](https://dash.cloudflare.com/pages)
2. Look for `nexa-web` in project list
3. If not found, first deployment will create it

### 6. Cloudflare Pages Environment Variables

Navigate to: **Cloudflare Dashboard** → **Pages** → **nexa-web** → **Settings** → **Environment variables**

Add these for **Production** environment:

- [ ] `API_BASE_URL` = `https://api.nexapymesoft.com`
- [ ] `API_PATH_PREFIX` = `/api`
- [ ] `GOOGLE_CLIENT_ID_WEB` = `[your-google-web-client-id]`
- [ ] `GOOGLE_SERVER_CLIENT_ID` = `[your-google-server-client-id]`
- [ ] `APPLE_SERVICE_ID` = `com.pymesoft.nexa.web`
- [ ] `APPLE_REDIRECT_URI` = `https://app.nexapymesoft.com/auth/callback`

**Optional (Places autocomplete):**
- [ ] `PLACES_BIAS_LAT` = `39.7392`
- [ ] `PLACES_BIAS_LNG` = `-104.9903`
- [ ] `PLACES_COMPONENTS` = `country:us`

### 7. Local Development Environment

- [ ] Flutter SDK installed (`flutter --version`)
- [ ] Flutter version 3.9.0 or higher
- [ ] Git installed and configured
- [ ] Repository cloned locally

**Verify Flutter:**
```bash
flutter --version
# Should show: Flutter 3.9.0 or higher

flutter doctor
# Should show: No issues found (or only optional items)
```

### 8. Local Testing (Before First Push)

Run these commands locally to ensure they pass:

```bash
# Navigate to project directory
cd /Volumes/Macintosh\ HD/Users/juansuarez/nexa

# Get dependencies
flutter pub get
# Should complete without errors

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs
# Should complete successfully

# Analyze code
flutter analyze
# Should show: No issues found!

# Run tests
flutter test
# Should show: All tests passed!

# Build for web
flutter build web --release
# Should complete and create build/web directory

# Verify build output
ls -la build/web/index.html
# Should exist
```

- [ ] `flutter pub get` succeeds
- [ ] `flutter pub run build_runner build` succeeds
- [ ] `flutter analyze` shows no errors
- [ ] `flutter test` all tests pass
- [ ] `flutter build web --release` succeeds
- [ ] `build/web/index.html` exists after build

## First Deployment Checklist

### 9. Commit and Push Workflow

```bash
# Add workflow files
git add .github/workflows/flutter-web-deploy.yml
git add .github/workflows/*.md

# Commit
git commit -m "Add Flutter web CI/CD pipeline"

# Push to trigger workflow
git push origin android1
```

- [ ] Workflow files committed
- [ ] Changes pushed to `android1` or `main` branch
- [ ] Push includes changes to files matching workflow paths

### 10. Monitor First Deployment

Navigate to: **GitHub Repository** → **Actions** tab

- [ ] Workflow run appears in Actions tab
- [ ] Workflow named "Flutter Web CI/CD" is running
- [ ] Click on workflow run to see details

**Expected progression:**

1. **Analyze & Test** job starts
   - [ ] "Setup Flutter SDK" step succeeds
   - [ ] "Run Flutter analyzer" step succeeds (✅)
   - [ ] "Run Flutter tests" step succeeds (✅)

2. **Build Web** job starts (after Analyze succeeds)
   - [ ] "Build Flutter web (release)" step succeeds (✅)
   - [ ] "Verify build output" step succeeds (✅)
   - [ ] "Upload build artifacts" step succeeds (✅)

3. **Deploy to Cloudflare** job starts (after Build succeeds)
   - [ ] "Download build artifacts" step succeeds (✅)
   - [ ] "Deploy to Cloudflare Pages" step succeeds (✅)
   - [ ] "Deployment summary" step succeeds (✅)

### 11. Verify Deployment

After workflow completes:

- [ ] All jobs show green checkmarks (✅)
- [ ] No red X marks (failures)
- [ ] Deployment job completed successfully

**Check Cloudflare Pages:**
1. Go to [Cloudflare Pages](https://dash.cloudflare.com/pages)
2. Click **nexa-web** project
3. Click **Deployments** tab

- [ ] New deployment appears with recent timestamp
- [ ] Deployment status is "Success"
- [ ] Preview URL is shown

**Check Live Site:**
1. Visit: https://app.nexapymesoft.com
2. Clear browser cache (Cmd+Shift+R / Ctrl+Shift+R)

- [ ] Site loads successfully
- [ ] No console errors (F12 → Console)
- [ ] Login works correctly
- [ ] API calls work correctly

## Troubleshooting Checklist

If deployment fails, check these in order:

### Issue: "Analyze & Test" Job Fails

**Check flutter analyze:**
```bash
flutter analyze
```
- [ ] Fix all errors reported
- [ ] Run `flutter pub get` if dependency errors
- [ ] Commit fixes and push again

**Check flutter test:**
```bash
flutter test
```
- [ ] Fix failing tests
- [ ] Update test expectations if needed
- [ ] Commit fixes and push again

### Issue: "Build Web" Job Fails

**Check build locally:**
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter build web --release
```
- [ ] Verify build completes locally
- [ ] Check for dependency conflicts
- [ ] Verify `pubspec.yaml` is valid
- [ ] Commit fixes and push again

### Issue: "Deploy to Cloudflare" Job Fails

**Check Cloudflare credentials:**
- [ ] Verify `CLOUDFLARE_API_TOKEN` is correct
- [ ] Verify `CLOUDFLARE_ACCOUNT_ID` is correct
- [ ] Check token hasn't expired
- [ ] Verify token has correct permissions

**Check Cloudflare project:**
- [ ] Project `nexa-web` exists or will be created
- [ ] No conflicting deployments in progress
- [ ] Cloudflare account is active

**Re-run deployment:**
1. Go to GitHub Actions → Failed workflow
2. Click "Re-run jobs" → "Re-run failed jobs"
- [ ] Deployment succeeds on retry

### Issue: Site Loads but Features Don't Work

**Check environment variables:**
1. Cloudflare Pages → nexa-web → Settings → Environment variables
- [ ] All required variables are set
- [ ] Values are correct (not placeholder text)
- [ ] Variables are set for "Production" environment

**Check browser console:**
1. Open site in browser
2. Press F12 → Console tab
- [ ] No 401/403 errors (auth issues)
- [ ] No CORS errors (API issues)
- [ ] No undefined variable errors

**Check API connection:**
- [ ] Backend API is running at 198.58.111.243
- [ ] API_BASE_URL points to correct backend
- [ ] Backend accepts requests from frontend domain

## Post-Deployment Checklist

### 12. Verify CI/CD Pipeline Works

**Test with a small change:**

```bash
# Make a trivial change
echo "// Test comment" >> lib/main.dart

# Commit and push
git add lib/main.dart
git commit -m "test: verify CI/CD pipeline"
git push origin android1
```

- [ ] Workflow triggers automatically
- [ ] Workflow completes successfully
- [ ] Change appears on live site

**Test preview deployment (optional):**

```bash
# Create a test branch
git checkout -b test/preview-deployment

# Make a change
echo "// Preview test" >> lib/main.dart

# Push and create PR
git add lib/main.dart
git commit -m "test: preview deployment"
git push origin test/preview-deployment

# Create PR to main on GitHub
```

- [ ] Pull request created
- [ ] Workflow runs for PR
- [ ] Preview deployment created
- [ ] Preview URL accessible

### 13. Team Onboarding

Share documentation with team:

- [ ] Share `QUICK_START.md` for quick reference
- [ ] Share `FLUTTER_WEB_CI_CD_SETUP.md` for detailed docs
- [ ] Share `DEPLOYMENT_SUMMARY.md` for overview
- [ ] Explain when workflows trigger
- [ ] Explain how to view deployment status

### 14. Monitoring Setup

Set up ongoing monitoring:

- [ ] Bookmark GitHub Actions page
- [ ] Enable GitHub notifications for failed workflows
- [ ] Bookmark Cloudflare Pages deployments page
- [ ] Set up uptime monitoring for app.nexapymesoft.com (optional)
- [ ] Configure Cloudflare Analytics (built-in, no setup needed)

### 15. Maintenance Plan

- [ ] Schedule regular dependency updates (`flutter pub upgrade`)
- [ ] Review workflow logs weekly
- [ ] Monitor Cloudflare usage/limits
- [ ] Rotate API tokens quarterly (security best practice)
- [ ] Update Flutter SDK version in workflow as needed

## Final Verification

All checks should be complete:

- ✅ GitHub Secrets configured
- ✅ Cloudflare API Token created
- ✅ Cloudflare Pages project exists
- ✅ Environment variables set
- ✅ Local tests pass
- ✅ First deployment succeeded
- ✅ Live site accessible and working
- ✅ CI/CD triggers on new pushes
- ✅ Team is onboarded
- ✅ Monitoring is in place

## Emergency Contacts / Resources

### Documentation
- Quick Start: `.github/workflows/QUICK_START.md`
- Full Setup: `.github/workflows/FLUTTER_WEB_CI_CD_SETUP.md`
- Overview: `.github/workflows/DEPLOYMENT_SUMMARY.md`

### External Resources
- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)
- [Flutter Web Docs](https://docs.flutter.dev/platform-integration/web)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Wrangler CLI Docs](https://developers.cloudflare.com/workers/wrangler/)

### Support Channels
- Cloudflare Community: https://community.cloudflare.com/
- Flutter Discord: https://discord.gg/flutter
- GitHub Actions Forum: https://github.community/

## Status Tracking

Date: _______________

Completed by: _______________

Notes:
```
_________________________________________________________

_________________________________________________________

_________________________________________________________
```

---

**Checklist Version**: 1.0.0
**Last Updated**: October 24, 2025
**Status**: Ready for use ✅
