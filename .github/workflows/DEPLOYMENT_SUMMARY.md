# CI/CD Deployment Summary

## Overview

Your Nexa project now has **two separate CI/CD pipelines** for different parts of the application:

1. **Backend Pipeline** (`deploy.yml`) - Express.js API deployment to Linode
2. **Frontend Pipeline** (`flutter-web-deploy.yml`) - Flutter web deployment to Cloudflare Pages

## Pipeline Comparison

| Feature | Backend Pipeline | Frontend Pipeline |
|---------|-----------------|-------------------|
| **File** | `deploy.yml` | `flutter-web-deploy.yml` |
| **Technology** | Express.js (Node.js) | Flutter Web (Dart) |
| **Deploy Target** | Linode VPS (198.58.111.243) | Cloudflare Pages |
| **Triggers** | `backend/**` changes | `lib/**`, `web/**` changes |
| **Testing** | `npm test` | `flutter test` |
| **Linting** | `npm run lint` | `flutter analyze` |
| **Build** | `npm run build` (TypeScript) | `flutter build web --release` |
| **Deployment** | SSH to Linode + `deploy.sh` | Wrangler CLI to Cloudflare |
| **Branches** | `main`, `android1` | `main`, `android1` |

## How They Work Together

```
┌─────────────────────────────────────────────────────────────────┐
│                         PUSH TO GITHUB                          │
│                         (android1 branch)                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴──────────┐
                    │                      │
                    ▼                      ▼
    ┌───────────────────────┐  ┌──────────────────────┐
    │   Backend Changes?    │  │  Frontend Changes?   │
    │   (backend/**)        │  │  (lib/**, web/**)    │
    └───────────────────────┘  └──────────────────────┘
                    │                      │
            YES ────┘                      └──── YES
                    │                      │
                    ▼                      ▼
    ┌───────────────────────┐  ┌──────────────────────┐
    │  Backend CI/CD        │  │  Frontend CI/CD      │
    │  (deploy.yml)         │  │  (flutter-web-       │
    │                       │  │   deploy.yml)        │
    │  1. npm test          │  │  1. flutter analyze  │
    │  2. npm run lint      │  │  2. flutter test     │
    │  3. npm run build     │  │  3. flutter build    │
    │  4. SSH to Linode     │  │  4. Deploy to        │
    │  5. Run deploy.sh     │  │     Cloudflare Pages │
    └───────────────────────┘  └──────────────────────┘
                    │                      │
                    ▼                      ▼
    ┌───────────────────────┐  ┌──────────────────────┐
    │  Backend API Running  │  │  Frontend Web App    │
    │  198.58.111.243:3000  │  │  app.nexapymesoft.   │
    │  (Linode)             │  │  com (Cloudflare)    │
    └───────────────────────┘  └──────────────────────┘
```

## Deployment Scenarios

### Scenario 1: Only Backend Changes

```bash
# Example: Update API endpoint
git add backend/src/routes/events.ts
git commit -m "feat: add DELETE /events/:id endpoint"
git push origin android1

# Result:
# ✅ Backend pipeline runs (deploy.yml)
# ⊘ Frontend pipeline SKIPPED (no Flutter changes)
```

### Scenario 2: Only Frontend Changes

```bash
# Example: Update UI component
git add lib/features/events/presentation/pages/event_list_page.dart
git commit -m "feat: improve event list loading indicator"
git push origin android1

# Result:
# ⊘ Backend pipeline SKIPPED (no backend changes)
# ✅ Frontend pipeline runs (flutter-web-deploy.yml)
```

### Scenario 3: Both Backend and Frontend Changes

```bash
# Example: Add new feature with API + UI
git add backend/src/routes/notifications.ts
git add lib/features/notifications/
git commit -m "feat: add push notification system"
git push origin android1

# Result:
# ✅ Backend pipeline runs (deploy.yml)
# ✅ Frontend pipeline runs (flutter-web-deploy.yml)
# Both run in parallel!
```

### Scenario 4: Documentation or Config Changes

```bash
# Example: Update README
git add README.md
git commit -m "docs: update setup instructions"
git push origin android1

# Result:
# ⊘ Backend pipeline SKIPPED
# ⊘ Frontend pipeline SKIPPED
# (No code changes detected)
```

## Pipeline Independence

The pipelines are **completely independent**:

- They run in parallel when both are triggered
- One can fail without affecting the other
- Each has its own deployment target
- Each has its own secrets and configuration

### Example: Frontend breaks, Backend still deploys

```bash
git add lib/broken_code.dart backend/fixed_api.ts
git push

# Backend Pipeline:
# ✅ Tests pass
# ✅ Build succeeds
# ✅ Deploys to Linode

# Frontend Pipeline:
# ❌ flutter analyze fails (broken code)
# ⊘ Build SKIPPED
# ⊘ Deploy SKIPPED
# Backend is live, frontend is not updated
```

## File Structure

```
nexa/
├── .github/
│   └── workflows/
│       ├── deploy.yml                      # Backend CI/CD
│       ├── flutter-web-deploy.yml          # Frontend CI/CD ✨ NEW
│       ├── FLUTTER_WEB_CI_CD_SETUP.md      # Complete docs ✨ NEW
│       ├── QUICK_START.md                  # Quick reference ✨ NEW
│       └── DEPLOYMENT_SUMMARY.md           # This file ✨ NEW
├── backend/                                # Backend code (Express.js)
│   ├── src/
│   ├── package.json
│   └── ...
├── lib/                                    # Frontend code (Flutter)
│   ├── features/
│   ├── core/
│   └── ...
├── web/                                    # Web-specific files
│   ├── index.html
│   └── ...
└── pubspec.yaml                            # Flutter dependencies
```

## Required Secrets by Pipeline

### Backend Pipeline (deploy.yml)
```
Secrets:
- SERVER_SSH_KEY          (SSH private key for Linode)

Variables:
- SERVER_USER             (SSH username)
- SERVER_HOST             (198.58.111.243)
```

### Frontend Pipeline (flutter-web-deploy.yml)
```
Secrets:
- CLOUDFLARE_API_TOKEN    (Cloudflare API token) ✨ REQUIRED
- CLOUDFLARE_ACCOUNT_ID   (Cloudflare account ID) ✨ REQUIRED
```

**Note**: Backend and Frontend use completely different secrets.

## Deployment Targets

### Backend API
- **Platform**: Linode VPS
- **IP**: 198.58.111.243
- **Port**: 3000 (likely behind reverse proxy)
- **Domain**: api.nexapymesoft.com (assumed)
- **Method**: SSH + deploy.sh script
- **Process Manager**: Likely PM2 or systemd

### Frontend Web App
- **Platform**: Cloudflare Pages
- **URL**: app.nexapymesoft.com
- **CDN**: Cloudflare global network
- **Method**: Wrangler CLI direct upload
- **Hosting**: Static files (no server-side rendering)

## Environment Variables

### Backend Environment Variables
Set on **Linode server** (likely in `.env` file):

```bash
PORT=3000
NODE_ENV=production
DATABASE_URL=...
JWT_SECRET=...
GOOGLE_MAPS_API_KEY=...
OPENAI_API_KEY=...
# etc.
```

### Frontend Environment Variables
Set in **Cloudflare Pages Dashboard**:

```bash
API_BASE_URL=https://api.nexapymesoft.com
API_PATH_PREFIX=/api
GOOGLE_CLIENT_ID_WEB=...
GOOGLE_SERVER_CLIENT_ID=...
APPLE_SERVICE_ID=com.pymesoft.nexa.web
APPLE_REDIRECT_URI=https://app.nexapymesoft.com/auth/callback
# etc.
```

**Important**: Frontend vars are injected at build time via `--dart-define` flags (currently set in Cloudflare, not in GitHub Actions workflow).

## Branch Strategy

Both pipelines use the same branch strategy:

| Branch | Behavior |
|--------|----------|
| `main` | Auto-deploy to production |
| `android1` | Auto-deploy to production |
| `feature/*` | Run tests/builds, NO deploy |
| Pull Requests to `main` | Run tests, create preview (frontend only) |

## Testing Gates

### Backend (deploy.yml)
```
1. Type check (npm run lint)
2. Unit tests (npm test)
3. TypeScript build (npm run build)
4. Deploy if all pass
```

### Frontend (flutter-web-deploy.yml)
```
1. Code generation (build_runner)
2. Static analysis (flutter analyze)
3. Unit/widget tests (flutter test)
4. Production build (flutter build web)
5. Build verification
6. Deploy if all pass
```

## Preview Deployments

| Pipeline | Preview Support | URL Pattern |
|----------|-----------------|-------------|
| Backend | ❌ No | N/A |
| Frontend | ✅ Yes | `https://[branch-name].nexa-web.pages.dev` |

**Frontend previews** are created automatically for PRs targeting `main`. This allows testing changes before merging.

## Rollback Procedures

### Backend Rollback
1. SSH to Linode server
2. Checkout previous commit
3. Restart service (PM2/systemd)

OR

1. Create hotfix branch from working commit
2. Push to trigger new deployment

### Frontend Rollback
1. Cloudflare Pages Dashboard → Deployments
2. Find working deployment
3. Click "Rollback"

OR

1. Re-run previous successful GitHub Actions workflow

## Monitoring

### Backend Monitoring
- **Logs**: SSH to server, check application logs
- **Health**: Check API endpoints manually
- **Status**: GitHub Actions for deployment status

### Frontend Monitoring
- **Logs**: Cloudflare Pages Dashboard → Deployments
- **Health**: Visit app.nexapymesoft.com
- **Status**: GitHub Actions for deployment status
- **Analytics**: Cloudflare Analytics (built-in)

## Cost Comparison

| Service | Backend | Frontend |
|---------|---------|----------|
| **Platform** | Linode VPS | Cloudflare Pages |
| **Cost** | ~$5-60/month (depends on VPS size) | FREE (unlimited bandwidth) |
| **SSL** | Manual setup or Let's Encrypt | Automatic (included) |
| **CDN** | Not included | Global CDN included |
| **Bandwidth** | Limited by VPS plan | Unlimited |
| **Scaling** | Vertical (upgrade VPS) | Automatic |

## Key Differences

| Aspect | Backend | Frontend |
|--------|---------|----------|
| **Language** | TypeScript | Dart |
| **Runtime** | Node.js | Browser |
| **State** | Stateful (database, sessions) | Stateless (static files) |
| **Deployment** | Pull-based (SSH + script) | Push-based (upload files) |
| **Environment** | Server-side | Client-side |
| **Updates** | Requires restart | Instant (CDN cache) |

## Next Steps

### For Backend Pipeline (Existing)
- ✅ Already configured and working
- Consider adding automated tests if not present
- Monitor deployment logs regularly

### For Frontend Pipeline (New)
1. ✅ **Add GitHub Secrets** (see QUICK_START.md)
   - CLOUDFLARE_API_TOKEN
   - CLOUDFLARE_ACCOUNT_ID
2. ✅ **Verify Cloudflare project** exists (nexa-web)
3. ✅ **Push workflow** to trigger first deployment
4. ✅ **Monitor Actions tab** for results
5. ✅ **Test preview deployments** with a PR

## Troubleshooting

### Both Pipelines Running When They Shouldn't

**Symptom**: Backend pipeline runs when only frontend changed (or vice versa)

**Cause**: Path filters may overlap or be too broad

**Solution**: Check the `paths` configuration in each workflow:
- Backend: `backend/**`
- Frontend: `lib/**`, `web/**`, `assets/**`, `pubspec.yaml`

### Workflow Not Triggering

**Symptom**: Push doesn't trigger any workflow

**Causes**:
1. Changes don't match any path filters
2. Branch not listed in workflow triggers
3. Workflow file has syntax errors

**Solutions**:
1. Check if changed files match path patterns
2. Verify branch name matches workflow triggers
3. Validate YAML syntax (use online validator)

### Both Pipelines Needed Changes

If you need to modify configuration affecting both:

```bash
# Example: Update API URL in both backend and frontend
git add backend/src/config.ts
git add lib/core/config/api_config.dart
git commit -m "fix: update API endpoint URL"
git push origin android1

# Both pipelines will run:
# ✅ Backend pipeline
# ✅ Frontend pipeline
```

## Migration Notes

### Before (Single Pipeline)
- Only backend had automated deployment
- Frontend deployed manually or via Cloudflare Git integration
- No automated testing for frontend changes

### After (Dual Pipeline)
- ✅ Backend has automated deployment (unchanged)
- ✅ Frontend has automated deployment (NEW)
- ✅ Both have automated testing
- ✅ Frontend has preview deployments
- ✅ Fail-fast behavior prevents broken builds

## Documentation Files

| File | Purpose | Audience |
|------|---------|----------|
| `QUICK_START.md` | 5-minute setup guide | New team members |
| `FLUTTER_WEB_CI_CD_SETUP.md` | Complete documentation | DevOps, troubleshooting |
| `DEPLOYMENT_SUMMARY.md` | Pipeline overview (this file) | Everyone |
| `flutter-web-deploy.yml` | Workflow definition | CI/CD system |

## Best Practices

1. **Test Locally First**: Run `flutter analyze` and `flutter test` before pushing
2. **Use Pull Requests**: Test changes in preview environment
3. **Monitor Deployments**: Check Actions tab after each push
4. **Small Commits**: Easier to rollback if something breaks
5. **Meaningful Messages**: Use conventional commits (feat:, fix:, etc.)
6. **Review Logs**: Check deployment logs if anything fails
7. **Update Dependencies**: Keep Flutter and packages up to date

## Support

- **Quick Setup**: See [QUICK_START.md](./QUICK_START.md)
- **Detailed Docs**: See [FLUTTER_WEB_CI_CD_SETUP.md](./FLUTTER_WEB_CI_CD_SETUP.md)
- **Backend Pipeline**: See existing [deploy.yml](./deploy.yml)
- **Cloudflare Docs**: https://developers.cloudflare.com/pages/
- **Flutter Docs**: https://docs.flutter.dev/

---

**Created**: October 24, 2025
**Status**: Production Ready ✅
**Pipelines**: 2 (Backend + Frontend)
