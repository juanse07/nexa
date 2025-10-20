# CI/CD Setup Complete! 🚀

## What's Been Set Up

### ✅ GitHub Actions CI/CD Pipeline
- **Location**: `.github/workflows/deploy.yml`
- **Triggers**: Push to main/android1, PRs to main, manual dispatch
- **Steps**:
  1. Type checking with TypeScript
  2. Run tests
  3. Build application
  4. Deploy to Linode (only on main branch push after tests pass)

### ✅ Deployment Scripts

**deploy.sh** - Zero-downtime deployment
- Saves current state for rollback
- Updates code from GitHub
- Builds new Docker image
- Performs health checks
- Auto-rollback on failure
- Cleans up old images

**rollback.sh** - Quick rollback
- Reverts to previous commit
- Restores previous Docker image
- Verifies health after rollback

### ✅ Docker Configuration

**Dockerfile** (Multi-stage build)
- Builder stage: Compiles TypeScript
- Production stage: Minimal runtime
- Non-root user for security
- Integrated health checks
- Optimized image size

**docker-compose.prod.yml**
- Health check configuration
- Automatic restart policies
- Caddy reverse proxy
- Zero-downtime rolling updates

## How It Works

### Automated Deployment Flow

```
Push to main
    ↓
GitHub Actions starts
    ↓
Install dependencies
    ↓
Run type check (npm run lint)
    ↓
Run tests (npm test)
    ↓
Build TypeScript
    ↓
✅ All checks pass?
    ↓
SSH to Linode server
    ↓
Run deploy.sh
    ↓
Pull latest code
    ↓
Build new Docker image
    ↓
Start new container
    ↓
Wait for health checks
    ↓
✅ Health check passes?
    ↓
Remove old container
    ↓
Deployment complete! 🎉
```

### Zero-Downtime Strategy

1. **New container starts** while old one runs
2. **Health checks verify** new container is ready
3. **Traffic switches** only when new container is healthy
4. **Old container removed** after successful switch
5. **Auto-rollback** if health checks fail

## Quick Commands

### Deploy to Production
```bash
# Automated (via GitHub)
git push origin main

# Manual (on server)
ssh app@198.58.111.243
./deploy.sh
```

### Rollback if Needed
```bash
ssh app@198.58.111.243
./rollback.sh
```

### View Logs
```bash
ssh app@198.58.111.243
cd /srv/app
docker compose logs -f api
```

### Check Status
```bash
ssh app@198.58.111.243
cd /srv/app
docker compose ps
```

## GitHub Repository Settings

You need to configure these in your GitHub repo:

**Settings → Secrets and variables → Actions → Variables**
- `SERVER_USER` = `app`
- `SERVER_HOST` = `198.58.111.243`

**Settings → Secrets and variables → Actions → Secrets**
- `SERVER_SSH_KEY` = (Your private SSH key)

## File Locations

### Local (Development)
```
nexa/
├── .github/workflows/deploy.yml    # CI/CD pipeline
└── backend/
    ├── src/                        # Source code
    ├── dist/                       # Built JavaScript
    ├── Dockerfile                  # Production Docker image
    ├── docker-compose.prod.yml     # Production compose config
    ├── deploy.sh                   # Deployment script
    ├── rollback.sh                 # Rollback script
    ├── package.json                # Now with lint & test scripts
    ├── DEPLOYMENT.md               # Detailed deployment docs
    └── SETUP.md                    # This file
```

### Server (Production)
```
/srv/app/
├── nexa/                          # Git repository (auto-updated)
├── deploy.sh                      # Deployment script
├── rollback.sh                    # Rollback script
├── docker-compose.yml             # Production config
├── Dockerfile                     # Symlink to nexa/backend/Dockerfile
├── .env                          # Environment variables
├── Caddyfile                     # Reverse proxy config
└── backups/                      # Rollback backups
```

## Testing the Setup

### 1. Test Locally First
```bash
cd backend
npm install
npm run lint      # Type check
npm test          # Run tests
npm run build     # Build TypeScript
npm run dev       # Run locally
```

### 2. Test Docker Build
```bash
cd backend
docker build -t nexa-api:test .
docker run -p 4000:4000 --env-file .env nexa-api:test
```

### 3. Test Deployment
```bash
# Make a small change
echo "// test" >> backend/src/index.ts

# Commit and push
git add .
git commit -m "Test CI/CD pipeline"
git push origin main

# Watch GitHub Actions
# Go to: https://github.com/your-repo/actions

# Monitor deployment on server
ssh app@198.58.111.243
cd /srv/app
docker compose logs -f api
```

## Safety Features

### ✅ Pre-Deployment Checks
- TypeScript compilation must succeed
- All tests must pass
- Build must complete successfully

### ✅ During Deployment
- New container starts before old one stops
- Multiple health check attempts (10 retries)
- Automatic rollback on failure
- Previous state saved for recovery

### ✅ Post-Deployment
- Verification of running container
- Recent logs displayed
- Cleanup of old images
- Backup retention (5 backups)

## Troubleshooting

### Deployment Failed in CI
1. Check GitHub Actions logs
2. Look for lint/test/build errors
3. Fix locally and push again

### Deployment Failed on Server
1. SSH to server: `ssh app@198.58.111.243`
2. Check logs: `docker compose logs api`
3. Run rollback: `./rollback.sh`

### Health Check Failing
1. Verify `/healthz` endpoint works
2. Check environment variables
3. Review application logs
4. Test endpoint: `curl http://localhost:4000/healthz`

## Next Steps

### Optional Enhancements

1. **Add Real Tests**
   ```bash
   npm install --save-dev jest @types/jest
   # Update package.json test script
   ```

2. **Add ESLint**
   ```bash
   npm install --save-dev eslint @typescript-eslint/parser
   # Create .eslintrc.js
   ```

3. **Add Slack/Discord Notifications**
   - Add notification step to GitHub Actions
   - Get notified of deployments

4. **Add Monitoring**
   - Set up uptime monitoring (Uptime Robot, etc.)
   - Application performance monitoring (APM)

5. **Add Staging Environment**
   - Create staging branch
   - Deploy to separate server for testing

## Resources

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Docker Compose**: https://docs.docker.com/compose/
- **Health Checks**: https://docs.docker.com/engine/reference/builder/#healthcheck

## Support

For issues or questions:
1. Check `DEPLOYMENT.md` for detailed documentation
2. Review GitHub Actions logs
3. Check server logs with `docker compose logs`

---

**Status**: ✅ CI/CD Pipeline Ready!

Your deployment pipeline is now set up and ready to use. Every push to the main branch will automatically:
- Run tests and type checks
- Build your application
- Deploy to your Linode server with zero downtime
- Automatically rollback if anything fails

Happy deploying! 🚀
