# Deployment Guide

## Overview

This project uses a CI/CD pipeline with GitHub Actions for automated testing, linting, and zero-downtime deployment to a Linode server.

## CI/CD Pipeline

### GitHub Actions Workflow

The workflow (`.github/workflows/deploy.yml`) runs on:
- Push to `main` or `android1` branches
- Pull requests to `main`
- Manual trigger via `workflow_dispatch`

### Pipeline Stages

1. **Test & Build** (runs on all triggers)
   - Checkout code
   - Install dependencies
   - Run TypeScript type checking
   - Run tests
   - Build TypeScript to JavaScript
   - Upload build artifacts

2. **Deploy** (only on push to `main`)
   - Only runs if tests and build pass
   - Connects to Linode server via SSH
   - Executes deployment script

## Zero-Downtime Deployment

The deployment uses Docker Compose with health checks to ensure zero downtime:

1. **Pull latest code** from GitHub
2. **Build new Docker image** with updated code
3. **Tag old image** for potential rollback
4. **Start new container** alongside the old one
5. **Wait for health checks** to pass
6. **Remove old container** only after new one is healthy
7. **Verify deployment** with multiple health check attempts

### Health Checks

The API must respond successfully to `GET /healthz` before deployment is considered successful.

## Server Setup

### Required GitHub Secrets & Variables

Configure in GitHub repo settings → Secrets and variables → Actions:

**Variables:**
- `SERVER_USER`: SSH username (e.g., `app`)
- `SERVER_HOST`: Server IP or hostname (e.g., `198.58.111.243`)

**Secrets:**
- `SERVER_SSH_KEY`: Private SSH key for authentication

### Server Directory Structure

```
/srv/app/
├── nexa/                  # Git repository
│   └── backend/
├── deploy.sh              # Deployment script
├── rollback.sh            # Rollback script
├── docker-compose.yml     # Production Docker Compose config
├── Dockerfile             # Symlink to nexa/backend/Dockerfile
├── .env                   # Environment variables
├── Caddyfile             # Caddy reverse proxy config
└── backups/              # Deployment backups
    ├── last_commit.txt
    └── last_image.txt
```

## Manual Operations

### Deploy to Production

```bash
# SSH into server
ssh app@198.58.111.243

# Run deployment
cd ~
./deploy.sh
```

### Rollback Deployment

If something goes wrong, rollback to the previous version:

```bash
# SSH into server
ssh app@198.58.111.243

# Run rollback
cd ~
./rollback.sh
```

### View Logs

```bash
# SSH into server
ssh app@198.58.111.243

cd /srv/app

# View all logs
docker compose logs -f

# View only API logs
docker compose logs -f api

# View last 100 lines
docker compose logs --tail=100 api
```

### Restart Services

```bash
cd /srv/app

# Restart API only
docker compose restart api

# Restart all services
docker compose restart
```

### Check Service Status

```bash
cd /srv/app

# View running containers
docker compose ps

# Check health status
docker compose ps api
```

## Local Development

### Run Locally

```bash
cd backend
npm install
npm run dev
```

### Build Locally

```bash
cd backend
npm run build
```

### Type Check

```bash
cd backend
npm run lint
```

### Run Tests

```bash
cd backend
npm test
```

### Test Docker Build

```bash
cd backend
docker build -t nexa-api:test .
docker run -p 4000:4000 --env-file .env nexa-api:test
```

## Deployment Features

### ✅ Zero Downtime
- New container starts before old one stops
- Health checks ensure new version is working
- Traffic switches only when ready

### ✅ Automatic Rollback
- Failed health checks trigger automatic rollback
- Previous image is tagged for quick restoration
- Commit history preserved for manual rollback

### ✅ Safety Checks
- Tests must pass before deployment
- Type checking prevents runtime errors
- Multiple health check attempts
- Backup of previous state

### ✅ Logging & Monitoring
- Colored output for easy reading
- Detailed logs at each step
- Recent application logs shown after deployment

## Troubleshooting

### Deployment Failed

1. Check GitHub Actions logs for errors
2. SSH into server and check Docker logs
3. Run rollback if needed: `./rollback.sh`

### Health Check Failing

1. Check if `/healthz` endpoint exists
2. Verify environment variables are set
3. Check database connectivity
4. Review application logs

### Docker Issues

```bash
# Check container status
docker compose ps

# View detailed container info
docker inspect nexa-api

# Check resource usage
docker stats

# Rebuild without cache
docker compose build --no-cache
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R app:app /srv/app

# Fix script permissions
chmod +x /srv/app/deploy.sh
chmod +x /srv/app/rollback.sh
```

## Environment Variables

Required environment variables in `/srv/app/.env`:

```env
# Server Configuration
NODE_ENV=production
PORT=4000

# Database
MONGO_URI=mongodb://...

# JWT Secret
BACKEND_JWT_SECRET=your-secure-random-jwt-secret

# OpenAI API (Required for AI features)
# - Document extraction from images/PDFs
# - AI chat assistant for event creation
# - Timesheet analysis from sign-in sheets
OPENAI_API_KEY=your-openai-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_VISION_MODEL=gpt-4o-mini
OPENAI_TEXT_MODEL=gpt-4o-mini
OPENAI_ORG_ID=

# OAuth Configuration
GOOGLE_CLIENT_ID_WEB=...
GOOGLE_SERVER_CLIENT_ID=...
APPLE_BUNDLE_ID=...
APPLE_SERVICE_ID=...

# CORS
ALLOWED_ORIGINS=https://app.nexapymesoft.com
```

## Monitoring

### Health Check Endpoint

```bash
# From server
curl http://localhost:4000/healthz

# From outside (through Caddy)
curl https://your-domain.com/healthz
```

### Container Health

```bash
docker inspect nexa-api | grep -A 10 Health
```

## Best Practices

1. **Always test locally** before pushing to main
2. **Review logs** after each deployment
3. **Keep backups** of working configurations
4. **Monitor health** after deployment
5. **Use rollback** immediately if issues detected
6. **Update documentation** when making changes

## Security Notes

- API runs as non-root user inside container
- Minimal Alpine Linux base image
- Production dependencies only in final image
- Environment variables not committed to repo
- SSH key authentication for deployments
