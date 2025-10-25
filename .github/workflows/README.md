# Nexa CI/CD Workflows

This directory contains automated CI/CD pipelines for the Nexa event staffing management platform.

## Quick Links

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[QUICK_START.md](./QUICK_START.md)** | Get started in 5 minutes | 5 min |
| **[SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md)** | Verify correct setup | 10 min |
| **[DEPLOYMENT_SUMMARY.md](./DEPLOYMENT_SUMMARY.md)** | Understand pipeline architecture | 15 min |
| **[FLUTTER_WEB_CI_CD_SETUP.md](./FLUTTER_WEB_CI_CD_SETUP.md)** | Complete documentation | 30 min |

## Available Workflows

### 1. Backend CI/CD (`deploy.yml`)
**Status**: ✅ Production Ready

- **Purpose**: Deploy Express.js backend API to Linode VPS
- **Triggers**: Changes to `backend/**` on `main` or `android1` branches
- **Deployment**: SSH to 198.58.111.243, runs `deploy.sh`
- **Testing**: `npm test`, `npm run lint`, TypeScript compilation

### 2. Flutter Web CI/CD (`flutter-web-deploy.yml`)
**Status**: ✅ Production Ready (NEW)

- **Purpose**: Deploy Flutter web application to Cloudflare Pages
- **Triggers**: Changes to `lib/**`, `web/**`, `assets/**`, `pubspec.yaml` on `main` or `android1` branches
- **Deployment**: Direct upload to Cloudflare Pages via Wrangler CLI
- **Testing**: `flutter analyze`, `flutter test`, production build verification
- **Preview**: Automatic preview deployments for pull requests

## Visual Pipeline Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    PUSH TO GITHUB                            │
│                 (main or android1 branch)                     │
└──────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
    ┌───────▼────────┐             ┌───────▼────────┐
    │ Backend Changes│             │Frontend Changes│
    │  (backend/**)  │             │(lib/**,web/**) │
    └───────┬────────┘             └───────┬────────┘
            │                               │
            ▼                               ▼
    ┌───────────────┐             ┌────────────────┐
    │   deploy.yml  │             │ flutter-web-   │
    │               │             │   deploy.yml   │
    └───────┬───────┘             └───────┬────────┘
            │                               │
            ▼                               ▼
    ┌───────────────┐             ┌────────────────┐
    │ 1. npm test   │             │1. flutter      │
    │ 2. npm lint   │             │   analyze      │
    │ 3. npm build  │             │2. flutter test │
    │ 4. SSH deploy │             │3. flutter build│
    └───────┬───────┘             │4. Cloudflare   │
            │                     │   deploy       │
            ▼                     └───────┬────────┘
    ┌───────────────┐                    │
    │ Linode VPS    │                    ▼
    │ 198.58.111.243│             ┌────────────────┐
    │ API Running   │             │ Cloudflare     │
    └───────────────┘             │ Pages Deployed │
                                  │ app.nexa...com │
                                  └────────────────┘
```

## Setup Status

Use this checklist to track your setup progress:

- [ ] **Backend CI/CD**: Already configured ✅
- [ ] **Frontend CI/CD**: Needs setup (follow QUICK_START.md)
  - [ ] Add `CLOUDFLARE_API_TOKEN` to GitHub Secrets
  - [ ] Add `CLOUDFLARE_ACCOUNT_ID` to GitHub Secrets
  - [ ] Verify Cloudflare Pages project exists
  - [ ] Set environment variables in Cloudflare
  - [ ] Push workflow to trigger first deployment

## First-Time Setup

### New to this project?

1. **Read**: [QUICK_START.md](./QUICK_START.md) (5 minutes)
2. **Setup**: Follow the steps to add secrets and configure Cloudflare
3. **Test**: Run `flutter analyze` and `flutter test` locally
4. **Deploy**: Push to `android1` branch to trigger first deployment
5. **Verify**: Check GitHub Actions tab for deployment status

### Already familiar?

Jump straight to [SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md) to verify everything is configured correctly.

## Common Tasks

### View Deployment Status

**GitHub Actions:**
```
Repository → Actions tab → Select workflow run
```

**Cloudflare Pages:**
```
Cloudflare Dashboard → Pages → nexa-web → Deployments
```

### Trigger Manual Deployment

**Via GitHub:**
```
Actions tab → Flutter Web CI/CD → Run workflow
```

**Via CLI:**
```bash
# Install Wrangler
npm install -g wrangler

# Build and deploy
flutter build web --release
wrangler pages deploy build/web --project-name=nexa-web
```

### Test Changes Before Pushing

```bash
# Run locally to catch errors early
flutter analyze        # Check for code errors
flutter test          # Run unit tests
flutter build web     # Verify build works
```

### Create Preview Deployment

```bash
# Create a pull request to main branch
git checkout -b feature/my-feature
git push origin feature/my-feature
# Create PR on GitHub → Preview deployment created automatically
```

### Rollback Deployment

**Cloudflare Pages:**
```
Dashboard → Pages → nexa-web → Deployments
→ Find working deployment → Click "..." → Rollback
```

**GitHub Actions:**
```
Actions → Find working deployment → Re-run workflow
```

## Workflow Behavior

### When You Push Code

| Changed Files | Backend Pipeline | Frontend Pipeline |
|---------------|------------------|-------------------|
| `backend/**` | ✅ Runs | - Skipped |
| `lib/**` or `web/**` | - Skipped | ✅ Runs |
| Both | ✅ Runs | ✅ Runs (parallel) |
| Only docs (`.md`) | - Skipped | - Skipped |

### When You Create a PR

| PR Target | Backend Pipeline | Frontend Pipeline |
|-----------|------------------|-------------------|
| To `main` | ✅ Tests only (no deploy) | ✅ Tests + Preview deploy |
| To other branch | - Skipped | - Skipped |

### Quality Gates

Both pipelines enforce quality before deployment:

**Backend:**
1. TypeScript type checking
2. ESLint validation
3. Unit tests
4. Successful build

**Frontend:**
1. Dart static analysis (`flutter analyze`)
2. Unit and widget tests (`flutter test`)
3. Successful production build
4. Build output verification

If **any** step fails, deployment is **blocked**.

## File Structure

```
.github/workflows/
├── README.md                        # This file
│
├── deploy.yml                       # Backend CI/CD workflow
├── flutter-web-deploy.yml           # Frontend CI/CD workflow
│
├── QUICK_START.md                   # 5-minute setup guide
├── SETUP_CHECKLIST.md               # Setup verification checklist
├── DEPLOYMENT_SUMMARY.md            # Architecture overview
└── FLUTTER_WEB_CI_CD_SETUP.md       # Complete documentation
```

## Required Secrets

### GitHub Repository Secrets

Navigate to: **Settings** → **Secrets and variables** → **Actions**

**Backend Pipeline:**
- `SERVER_SSH_KEY` - SSH private key for Linode VPS

**Frontend Pipeline:**
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token (Edit Workers permission)
- `CLOUDFLARE_ACCOUNT_ID` - Your Cloudflare account ID

### Cloudflare Environment Variables

Navigate to: **Cloudflare Dashboard** → **Pages** → **nexa-web** → **Settings** → **Environment variables**

**Production:**
- `API_BASE_URL` - Backend API URL
- `API_PATH_PREFIX` - API path prefix
- `GOOGLE_CLIENT_ID_WEB` - Google OAuth client ID
- `GOOGLE_SERVER_CLIENT_ID` - Google server client ID
- `APPLE_SERVICE_ID` - Apple sign-in service ID
- `APPLE_REDIRECT_URI` - Apple redirect URI

## Monitoring

### GitHub Actions

- **URL**: https://github.com/[owner]/nexa/actions
- **View**: All workflow runs, logs, and artifacts
- **Notifications**: Configure in GitHub settings

### Cloudflare Pages

- **URL**: https://dash.cloudflare.com/pages
- **View**: Deployment history, logs, and analytics
- **Analytics**: Built-in (no configuration needed)

### Live Sites

- **Backend API**: http://198.58.111.243:3000 (or via domain)
- **Frontend Web**: https://app.nexapymesoft.com
- **Preview URLs**: `https://[branch-name].nexa-web.pages.dev`

## Troubleshooting

### Workflow Not Triggering

1. Check if changed files match path filters
2. Verify branch is `main` or `android1`
3. Check workflow file for syntax errors

### Workflow Fails at Analyze

```bash
# Run locally to see errors
flutter analyze

# Fix errors and push again
```

### Workflow Fails at Test

```bash
# Run locally to see failures
flutter test

# Fix tests and push again
```

### Deployment Fails

1. Verify GitHub Secrets are set correctly
2. Check Cloudflare API token is valid
3. Verify Cloudflare project exists
4. Review deployment logs in Actions tab

### Site Loads But Broken

1. Check Cloudflare environment variables
2. Check browser console for errors (F12)
3. Verify backend API is accessible
4. Clear browser cache and hard reload

## Best Practices

1. **Test Locally First**: Always run `flutter analyze` and `flutter test` before pushing
2. **Small Commits**: Easier to debug and rollback
3. **Meaningful Messages**: Use conventional commits (feat:, fix:, docs:)
4. **Use Pull Requests**: Test in preview environment before merging
5. **Monitor Deployments**: Check Actions tab after each push
6. **Keep Updated**: Regularly update dependencies and Flutter SDK

## Performance

### Pipeline Duration

**Backend (deploy.yml):**
- Analyze & Test: ~2-3 minutes
- Deploy: ~1-2 minutes
- **Total**: ~3-5 minutes

**Frontend (flutter-web-deploy.yml):**
- Analyze & Test: ~3-4 minutes
- Build: ~4-5 minutes
- Deploy: ~1-2 minutes
- **Total**: ~8-11 minutes

### Optimization

Both pipelines use caching to speed up builds:
- Flutter SDK cached
- Pub dependencies cached
- npm dependencies cached
- Build artifacts cached

## Support

### Documentation

- **Quick Setup**: [QUICK_START.md](./QUICK_START.md)
- **Setup Verification**: [SETUP_CHECKLIST.md](./SETUP_CHECKLIST.md)
- **Architecture**: [DEPLOYMENT_SUMMARY.md](./DEPLOYMENT_SUMMARY.md)
- **Complete Guide**: [FLUTTER_WEB_CI_CD_SETUP.md](./FLUTTER_WEB_CI_CD_SETUP.md)

### External Resources

- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)
- [Flutter Web Docs](https://docs.flutter.dev/platform-integration/web)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Wrangler CLI Docs](https://developers.cloudflare.com/workers/wrangler/)

### Community

- [Cloudflare Community](https://community.cloudflare.com/)
- [Flutter Discord](https://discord.gg/flutter)
- [GitHub Actions Forum](https://github.community/)

## Version History

### v1.0.0 - October 24, 2025
- Initial Flutter web CI/CD pipeline
- Automated testing and analysis gates
- Cloudflare Pages deployment
- Preview deployments for PRs
- Comprehensive documentation

### Existing - Backend CI/CD
- Express.js backend deployment to Linode
- Automated testing and linting
- SSH-based deployment

## Contributing

When modifying workflows:

1. Test changes in a feature branch first
2. Use pull requests for review
3. Document changes in relevant `.md` files
4. Update this README if adding new workflows
5. Verify all tests pass before merging

## Security

- Never commit secrets or API tokens to Git
- Use GitHub Secrets for all sensitive data
- Rotate API tokens regularly (quarterly recommended)
- Review workflow logs for exposed secrets
- Use least-privilege permissions for all tokens

## License

This CI/CD configuration is part of the Nexa project. See project root for license information.

---

**Last Updated**: October 24, 2025
**Maintained By**: DevOps Team
**Status**: Production Ready ✅

**Questions?** Start with [QUICK_START.md](./QUICK_START.md)
