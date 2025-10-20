#!/usr/bin/env bash
#
# Zero-downtime deployment script for Nexa backend
# This script performs a rolling update using Docker Compose
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_DIR="/srv/app"
REPO_DIR="/srv/app/nexa"
BACKUP_DIR="/srv/app/backups"
MAX_BACKUPS=5

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log_info "Starting zero-downtime deployment..."

# Step 1: Save current state for rollback
log_info "[1/7] Saving current state for rollback..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

cd "$REPO_DIR"
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "$CURRENT_COMMIT" > "$BACKUP_DIR/last_commit.txt"

# Backup current docker image
docker compose -f "$DEPLOY_DIR/docker-compose.yml" images api -q > "$BACKUP_DIR/last_image.txt" || true

log_success "Backup saved: $CURRENT_COMMIT"

# Step 2: Update repository
log_info "[2/7] Updating repository from GitHub..."
cd "$REPO_DIR"
git fetch --all

# Detect which branch to use (android1 or main)
BRANCH="android1"
if git show-ref --verify --quiet refs/remotes/origin/android1; then
    BRANCH="android1"
elif git show-ref --verify --quiet refs/remotes/origin/main; then
    BRANCH="main"
fi

log_info "Using branch: $BRANCH"
NEW_COMMIT=$(git rev-parse origin/$BRANCH)

if [ "$CURRENT_COMMIT" = "$NEW_COMMIT" ]; then
    log_warning "No new commits. Already at latest version."
    log_info "Current: $CURRENT_COMMIT"
    exit 0
fi

git reset --hard origin/$BRANCH
log_success "Updated to commit: $NEW_COMMIT"

# Step 3: Build new Docker image
log_info "[3/7] Building new Docker image..."
cd "$DEPLOY_DIR"
docker compose build --pull api

NEW_IMAGE_ID=$(docker compose images api -q)
log_success "New image built: $NEW_IMAGE_ID"

# Step 4: Tag current running container for potential rollback
log_info "[4/7] Tagging current image for rollback..."
OLD_IMAGE_ID=$(cat "$BACKUP_DIR/last_image.txt" 2>/dev/null || echo "none")
if [ "$OLD_IMAGE_ID" != "none" ] && [ -n "$OLD_IMAGE_ID" ]; then
    docker tag "$OLD_IMAGE_ID" "nexa-api:rollback" 2>/dev/null || log_warning "Could not tag old image"
fi

# Step 5: Perform rolling update with health check
log_info "[5/7] Deploying new version with health checks..."
log_info "Docker will wait for health checks to pass before removing old container..."

# Use --wait to ensure health checks pass before considering deployment successful
docker compose up -d --wait --no-deps api

# Step 6: Verify deployment
log_info "[6/7] Verifying deployment..."
sleep 5

# Check if container is running
if ! docker compose ps api | grep -q "Up"; then
    log_error "Container failed to start!"
    log_error "Rolling back..."
    bash "$DEPLOY_DIR/rollback.sh"
    exit 1
fi

# Check health endpoint
HEALTH_CHECK_RETRIES=10
HEALTH_CHECK_DELAY=3

for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
    log_info "Health check attempt $i/$HEALTH_CHECK_RETRIES..."

    if docker exec $(docker compose ps -q api) node -e "require('http').get('http://127.0.0.1:4000/healthz', r=>process.exit(r.statusCode===200?0:1)).on('error', ()=>process.exit(1))" 2>/dev/null; then
        log_success "Health check passed!"
        break
    fi

    if [ $i -eq $HEALTH_CHECK_RETRIES ]; then
        log_error "Health check failed after $HEALTH_CHECK_RETRIES attempts!"
        log_error "Rolling back..."
        bash "$DEPLOY_DIR/rollback.sh"
        exit 1
    fi

    sleep $HEALTH_CHECK_DELAY
done

# Step 7: Cleanup old images and backups
log_info "[7/7] Cleaning up..."

# Remove old backups (keep only last MAX_BACKUPS)
cd "$BACKUP_DIR"
ls -t backup_*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null || true

# Remove dangling images
docker image prune -f > /dev/null 2>&1 || true

log_success "==================================="
log_success "Deployment completed successfully!"
log_success "==================================="
log_info "Old commit: $CURRENT_COMMIT"
log_info "New commit: $NEW_COMMIT"
log_info ""
log_info "Recent logs:"
docker compose logs --tail=30 api

echo ""
log_info "To rollback this deployment, run: ./rollback.sh"
