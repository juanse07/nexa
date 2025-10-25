# Flutter Web CI/CD Setup Guide

> **Last Updated**: October 24, 2025
> **Workflow File**: `.github/workflows/flutter-web-deploy.yml`

## Overview

This CI/CD pipeline automates the build, test, and deployment process for the Nexa Flutter web application to Cloudflare Pages. It prevents failed builds from being deployed by enforcing quality gates at each stage.

## Pipeline Architecture

The pipeline consists of 4 jobs that run sequentially with fail-fast behavior:

```
1. Analyze & Test
   ├─ Flutter analyze (catches errors)
   ├─ Run unit/widget tests
   └─ Upload coverage report

2. Build Web (only if #1 succeeds)
   ├─ Build Flutter web --release
   ├─ Verify build output
   └─ Upload build artifacts

3. Deploy to Production (only if #2 succeeds + push to main/android1)
   ├─ Download build artifacts
   ├─ Deploy to Cloudflare Pages
   └─ Post-deployment verification

4. Deploy Preview (only if #2 succeeds + pull request)
   ├─ Download build artifacts
   ├─ Deploy preview to Cloudflare
   └─ Comment preview URL on PR
```

## How It Prevents Failed Builds

### 1. Static Analysis Gate
- **What**: `flutter analyze` runs before any build attempt
- **Why**: Catches compilation errors, type errors, and lint violations
- **Fail Behavior**: If analyze fails, the workflow stops immediately
- **Example**: Catches undefined variables, missing imports, type mismatches

### 2. Testing Gate
- **What**: `flutter test` runs all unit and widget tests
- **Why**: Ensures business logic works correctly
- **Fail Behavior**: If any test fails, the workflow stops
- **Example**: Validates API calls, state management, UI components

### 3. Build Verification Gate
- **What**: Verifies `build/web/index.html` exists after build
- **Why**: Ensures Flutter build completed successfully
- **Fail Behavior**: If build output is missing, deployment is skipped
- **Example**: Catches build crashes, missing dependencies

### 4. Artifact Dependency
- **What**: Deployment jobs depend on successful build job
- **Why**: Can't deploy what wasn't built successfully
- **Fail Behavior**: Deployment jobs never run if build fails
- **Example**: Network issues during build won't result in broken deployments

## Required GitHub Secrets

You must configure these secrets in your GitHub repository:

### Navigation
1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### Secrets to Add

#### 1. CLOUDFLARE_API_TOKEN
- **Description**: API token for Cloudflare Pages deployments
- **How to get it**:
  1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
  2. Click on your profile → **API Tokens**
  3. Click **Create Token**
  4. Use template **"Edit Cloudflare Workers"** or create custom token with:
     - Permissions: `Account > Cloudflare Pages > Edit`
     - Account Resources: `Include > [Your Account]`
  5. Copy the token (you won't see it again!)
- **Value format**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

#### 2. CLOUDFLARE_ACCOUNT_ID
- **Description**: Your Cloudflare account ID
- **How to get it**:
  1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
  2. Click on **Pages** or **Workers & Pages**
  3. Your Account ID is shown on the right sidebar

  OR

  1. Go to any domain in your Cloudflare account
  2. Scroll down to **API** section in the sidebar
  3. Copy the **Account ID**
- **Value format**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` (32 characters)

### Verification

After adding secrets, verify they're set correctly:

```bash
# In your GitHub repository Settings → Secrets and variables → Actions
# You should see:
CLOUDFLARE_API_TOKEN        [Set]
CLOUDFLARE_ACCOUNT_ID       [Set]
```

## Cloudflare Pages Project Configuration

The pipeline deploys to a Cloudflare Pages project named **`nexa-web`**. Ensure this project exists:

### Option 1: Use Existing Project
If you already have a Cloudflare Pages project for Nexa:
1. Note the project name (e.g., `nexa-web`)
2. If it's different, update line 147 in the workflow file:
   ```yaml
   command: pages deploy build/web --project-name=YOUR_PROJECT_NAME --commit-dirty=true
   ```

### Option 2: Create New Project via Dashboard
1. Go to [Cloudflare Pages](https://dash.cloudflare.com/pages)
2. Click **Create a project**
3. Choose **Direct Upload**
4. Name it **`nexa-web`**
5. Skip the initial upload (GitHub Actions will handle it)

### Option 3: Let Wrangler Create It
The first deployment will automatically create the project if it doesn't exist.

## Environment Variables in Cloudflare Pages

The workflow builds the Flutter web app **without** dart-define variables. Environment-specific configuration should be set in Cloudflare Pages:

### Navigation
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Click **Pages** → **nexa-web**
3. Click **Settings** → **Environment variables**

### Required Variables

Add these for **Production** environment:

```bash
# API Configuration
API_BASE_URL=https://api.nexapymesoft.com
API_PATH_PREFIX=/api

# Google Sign In
GOOGLE_CLIENT_ID_WEB=your-google-web-client-id
GOOGLE_SERVER_CLIENT_ID=your-google-server-client-id

# Apple Sign In
APPLE_SERVICE_ID=com.pymesoft.nexa.web
APPLE_REDIRECT_URI=https://app.nexapymesoft.com/auth/callback

# Optional: Places Autocomplete
PLACES_BIAS_LAT=39.7392
PLACES_BIAS_LNG=-104.9903
PLACES_COMPONENTS=country:us
```

### Build Command Override (Optional)

If you want Cloudflare to inject environment variables into the build, update the build settings:

1. Go to **Settings** → **Builds & deployments**
2. Set **Build command** to:
   ```bash
   flutter build web --release \
     --dart-define=API_BASE_URL=$API_BASE_URL \
     --dart-define=API_PATH_PREFIX=$API_PATH_PREFIX \
     --dart-define=GOOGLE_CLIENT_ID_WEB=$GOOGLE_CLIENT_ID_WEB \
     --dart-define=GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID \
     --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
     --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI
   ```
3. Set **Build output directory** to: `build/web`

**Note**: The current workflow uses GitHub Actions for building, so Cloudflare's build command won't run. If you want Cloudflare to build instead of GitHub Actions, you'll need to use the Cloudflare Git integration instead of Wrangler CLI.

## Triggering the Pipeline

### Automatic Triggers

The pipeline runs automatically when:

1. **Push to main or android1 branch** with changes to:
   - `lib/**` (Flutter source code)
   - `web/**` (Web-specific files)
   - `assets/**` (Images, fonts, etc.)
   - `pubspec.yaml` (Dependencies)
   - `pubspec.lock` (Dependency versions)
   - `analysis_options.yaml` (Linting rules)
   - `.github/workflows/flutter-web-deploy.yml` (Workflow itself)

2. **Pull Request to main branch** with changes to the same paths
   - Creates a preview deployment for testing

### Manual Trigger

You can manually trigger the workflow:

1. Go to **Actions** tab in GitHub
2. Click **Flutter Web CI/CD** workflow
3. Click **Run workflow** dropdown
4. Select branch and click **Run workflow**

## Understanding Workflow Behavior

### On Push to main/android1
```
Analyze & Test → Build Web → Deploy to Production
```
- Deploys to production Cloudflare Pages
- Accessible at your configured domain (e.g., `app.nexapymesoft.com`)

### On Pull Request
```
Analyze & Test → Build Web → Deploy Preview
```
- Deploys to preview URL (e.g., `pr-123-nexa-web.pages.dev`)
- Allows testing changes before merging
- Preview URL is posted in PR comments (if configured)

### On Push to Other Branches
```
Analyze & Test → Build Web → (No deployment)
```
- Validates code quality and buildability
- Does not deploy anywhere
- Useful for feature branches

## Monitoring Pipeline Runs

### View Workflow Status

1. Go to **Actions** tab in your GitHub repository
2. Click on a workflow run to see details
3. Each job shows its status: ✅ Success, ❌ Failed, 🟡 In Progress

### Understanding Job Results

#### ✅ All Green - Perfect!
```
✅ Analyze & Test
✅ Build Web
✅ Deploy to Cloudflare Pages
```
Your code is deployed successfully.

#### ❌ Analyze Fails
```
❌ Analyze & Test (flutter analyze found errors)
⊘  Build Web (skipped)
⊘  Deploy (skipped)
```
**Action**: Fix code errors shown in the analyze output.

#### ❌ Tests Fail
```
✅ Analyze & Test (analyze passed)
❌ Analyze & Test (tests failed)
⊘  Build Web (skipped)
⊘  Deploy (skipped)
```
**Action**: Fix failing tests shown in test output.

#### ❌ Build Fails
```
✅ Analyze & Test
❌ Build Web (flutter build web failed)
⊘  Deploy (skipped)
```
**Action**: Check build logs for compilation errors.

#### ❌ Deploy Fails
```
✅ Analyze & Test
✅ Build Web
❌ Deploy (Cloudflare deployment failed)
```
**Action**: Check Cloudflare credentials and project configuration.

## Troubleshooting

### Error: "flutter analyze failed"

**Symptom**: Workflow fails at "Run Flutter analyzer" step

**Causes**:
- Compilation errors in Dart code
- Type errors or null safety violations
- Lint rule violations

**Solution**:
1. Run locally: `flutter analyze`
2. Fix all reported errors
3. Commit and push changes

### Error: "flutter test failed"

**Symptom**: Workflow fails at "Run Flutter tests" step

**Causes**:
- Unit test assertions failing
- Widget tests not finding expected elements
- Test timeout or crashes

**Solution**:
1. Run locally: `flutter test`
2. Fix failing tests or update test expectations
3. Commit and push changes

### Error: "Build verification failed - index.html not found"

**Symptom**: Workflow fails at "Verify build output" step

**Causes**:
- Flutter build crashed without error message
- Missing dependencies
- Invalid pubspec.yaml configuration

**Solution**:
1. Run locally: `flutter build web --release`
2. Check for error messages
3. Verify `build/web/index.html` is created
4. Fix any issues and push

### Error: "Cloudflare API authentication failed"

**Symptom**: Deployment step fails with 401/403 error

**Causes**:
- Missing or incorrect `CLOUDFLARE_API_TOKEN`
- Missing or incorrect `CLOUDFLARE_ACCOUNT_ID`
- Token lacks required permissions

**Solution**:
1. Verify secrets are set in GitHub Settings → Secrets
2. Re-create Cloudflare API token with correct permissions
3. Update GitHub secret with new token
4. Re-run workflow

### Error: "Project not found: nexa-web"

**Symptom**: Deployment fails with "Project nexa-web does not exist"

**Causes**:
- Cloudflare Pages project doesn't exist
- Wrong project name in workflow

**Solution**:
1. Check project exists in Cloudflare Dashboard → Pages
2. If name is different, update workflow line 147
3. Or create new project named `nexa-web`

### Error: "wrangler command not found"

**Symptom**: Deployment step fails with command not found

**Causes**:
- Using old version of cloudflare/wrangler-action
- Incorrect action configuration

**Solution**:
1. Verify workflow uses `cloudflare/wrangler-action@v3`
2. Check GitHub Actions marketplace for latest version
3. Update workflow if needed

### Slow Build Times

**Symptom**: Workflow takes 10+ minutes to complete

**Optimization**:
1. Caching is already enabled for Flutter SDK and dependencies
2. Consider reducing test coverage if tests are slow
3. Use `flutter build web --release` instead of debug builds
4. Remove unnecessary dependencies from pubspec.yaml

### Preview Deployments Not Working

**Symptom**: PR deployments don't create preview URLs

**Causes**:
- PR not targeting `main` branch
- No changes to Flutter files (filtered by paths)
- Cloudflare Pages doesn't support branch deployments

**Solution**:
1. Verify PR targets `main` branch
2. Check that changes include files in `lib/`, `web/`, etc.
3. Verify Cloudflare project allows branch deployments

## Best Practices

### 1. Run Locally Before Pushing

Always test locally before pushing:

```bash
# Analyze code
flutter analyze

# Run tests
flutter test

# Build for web
flutter build web --release

# Verify output
ls -la build/web
```

### 2. Use Meaningful Commit Messages

Follow conventional commits for automatic changelog generation:

```bash
git commit -m "feat: add user profile page"
git commit -m "fix: resolve login redirect issue"
git commit -m "refactor: optimize event list rendering"
```

### 3. Create Pull Requests for Major Changes

- Use PRs to test changes in preview environment
- Get code review before merging to main
- Preview deployment allows stakeholder testing

### 4. Monitor Build Logs

- Check Actions tab after each push
- Review failed builds immediately
- Fix issues before they accumulate

### 5. Keep Dependencies Updated

```bash
# Update Flutter
flutter upgrade

# Update packages
flutter pub upgrade

# Test after updates
flutter test
```

### 6. Tag Releases

Create Git tags for production releases:

```bash
git tag -a v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1
```

## Customization Options

### Change Flutter Version

Edit line 14 and 56 in the workflow:

```yaml
flutter-version: '3.10.0'  # Change to desired version
```

### Add Additional Test Coverage

Edit line 68 to set minimum coverage threshold:

```yaml
- name: Run Flutter tests
  run: flutter test --coverage --reporter expanded --coverage-min=80
```

### Change Web Renderer

Edit line 88 to use different renderer:

```yaml
# Use HTML renderer (smaller bundle size, less features)
flutter build web --release --web-renderer html

# Use auto renderer (chooses best for each browser)
flutter build web --release --web-renderer auto
```

### Deploy to Different Cloudflare Project

Edit line 147:

```yaml
command: pages deploy build/web --project-name=my-custom-name --commit-dirty=true
```

### Add Slack Notifications

Add this step to the deploy job:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Security Considerations

### Secrets Management

- Never commit API tokens or secrets to Git
- Use GitHub Secrets for all sensitive data
- Rotate Cloudflare API tokens regularly
- Use least-privilege permissions for tokens

### Build Artifacts

- Artifacts are automatically deleted after 3 days
- Don't include sensitive data in build artifacts
- Source maps are enabled - be aware they expose code structure

### Environment Variables

- Environment variables in Cloudflare Pages are visible to anyone with access
- Don't store sensitive API keys in frontend environment variables
- Use backend proxy for sensitive API calls (as currently implemented)

## Rollback Procedures

If a deployment causes issues:

### Option 1: Rollback in Cloudflare Dashboard

1. Go to Cloudflare Pages → nexa-web → Deployments
2. Find the last known good deployment
3. Click **...** → **Rollback to this deployment**

### Option 2: Redeploy Previous Commit

```bash
# Find previous working commit
git log --oneline

# Create new branch from that commit
git checkout -b hotfix/rollback <commit-sha>

# Push to trigger new deployment
git push origin hotfix/rollback

# Merge to main once verified
git checkout main
git merge hotfix/rollback
git push origin main
```

### Option 3: Manual Deployment

```bash
# Install Wrangler locally
npm install -g wrangler

# Authenticate
wrangler login

# Build locally
flutter build web --release

# Deploy manually
wrangler pages deploy build/web --project-name=nexa-web
```

## Support and Resources

### Documentation
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [Cloudflare Pages Documentation](https://developers.cloudflare.com/pages/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Wrangler CLI Documentation](https://developers.cloudflare.com/workers/wrangler/)

### Common Commands

```bash
# Local development
flutter run -d chrome

# Analyze code
flutter analyze

# Run tests
flutter test

# Build for web
flutter build web --release

# Clean build cache
flutter clean && flutter pub get
```

### Getting Help

If you encounter issues not covered in this guide:

1. Check workflow logs in GitHub Actions tab
2. Review Cloudflare Pages deployment logs
3. Run commands locally to reproduce issues
4. Check Flutter and Cloudflare documentation
5. Search GitHub Issues for similar problems

## Changelog

### v1.0.0 - October 24, 2025
- Initial CI/CD pipeline creation
- Automated testing and analysis gates
- Cloudflare Pages deployment integration
- Preview deployments for pull requests
- Build artifact caching for performance
- Comprehensive error prevention mechanisms
