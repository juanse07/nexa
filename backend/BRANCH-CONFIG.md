# Branch Configuration

## Current Setup

The CI/CD pipeline is configured to deploy from **both** the `android1` and `main` branches.

## How It Works

### GitHub Actions Workflow
The workflow will:
- Run tests and linting on **any** push to `android1` or `main`
- Deploy to Linode only when pushing to `android1` or `main` (after tests pass)

### Deploy Script
The deploy script automatically detects which branch to use:
1. First checks for `android1` branch (priority)
2. Falls back to `main` if `android1` doesn't exist
3. Logs which branch is being deployed

## Current Active Branch: `android1`

### To Deploy from android1
```bash
# Make your changes
git add .
git commit -m "Your changes"
git push origin android1

# GitHub Actions will automatically:
# 1. Run type checks
# 2. Run tests
# 3. Build the app
# 4. Deploy to Linode ✓
```

### Switching to Main Branch Later

If you want to merge to main and deploy from there:

```bash
# Merge android1 into main
git checkout main
git merge android1
git push origin main

# The deploy script will automatically use main
```

## Manual Deployment

When you run `./deploy.sh` on the server, it will:
- Automatically detect and use the `android1` branch
- Pull latest changes from `origin/android1`
- Build and deploy

```bash
ssh app@198.58.111.243
./deploy.sh
# Output will show: "Using branch: android1"
```

## Branch Priority

The deployment script uses this priority:
1. **android1** (if exists) ← Current
2. **main** (fallback)

This means you can safely have both branches, and `android1` will be preferred.

## Workflow File Location

`.github/workflows/deploy.yml` - Line 60:
```yaml
if: github.event_name == 'push' && (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/android1')
```

## Testing

To test the deployment:

```bash
# Make a test change
echo "// test deployment" >> backend/src/index.ts

# Commit and push to android1
git add .
git commit -m "Test CI/CD from android1 branch"
git push origin android1

# Watch the deployment
# Go to: https://github.com/your-repo/actions
```

## Notes

- Both branches will trigger the full CI/CD pipeline
- Only pushes to these branches deploy (PRs only run tests)
- The server will always pull from whichever branch is configured
- Rollback script works regardless of which branch you're on
