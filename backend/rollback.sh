#!/usr/bin/env bash
#
# Rollback script for Nexa backend
# Reverts to the previous deployment
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

log_warning "╔════════════════════════════════════════╗"
log_warning "║   ROLLBACK TO PREVIOUS DEPLOYMENT      ║"
log_warning "╚════════════════════════════════════════╝"

# Check if backup exists
if [ ! -f "$BACKUP_DIR/last_commit.txt" ]; then
    log_error "No backup found! Cannot rollback."
    exit 1
fi

LAST_COMMIT=$(cat "$BACKUP_DIR/last_commit.txt")
CURRENT_COMMIT=$(cd "$REPO_DIR" && git rev-parse HEAD)

log_info "Current commit: $CURRENT_COMMIT"
log_info "Rolling back to: $LAST_COMMIT"

# Step 1: Revert repository
log_info "[1/4] Reverting repository to previous commit..."
cd "$REPO_DIR"
git reset --hard "$LAST_COMMIT"
log_success "Repository reverted"

# Step 2: Check if tagged rollback image exists
log_info "[2/4] Checking for rollback image..."
if docker images nexa-api:rollback -q | grep -q .; then
    log_info "Found tagged rollback image"

    # Tag it as the current image
    cd "$DEPLOY_DIR"
    docker tag nexa-api:rollback nexa-api:latest
else
    log_warning "No tagged image found, rebuilding from reverted commit..."
    cd "$DEPLOY_DIR"
    docker compose build --pull api
fi

# Step 3: Deploy the old version
log_info "[3/4] Deploying previous version..."
cd "$DEPLOY_DIR"
docker compose up -d --wait --no-deps api

# Wait for container to be healthy
sleep 5

# Step 4: Verify rollback
log_info "[4/4] Verifying rollback..."

HEALTH_CHECK_RETRIES=10
HEALTH_CHECK_DELAY=3

for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
    log_info "Health check attempt $i/$HEALTH_CHECK_RETRIES..."

    if docker exec $(docker compose ps -q api) node -e "require('http').get('http://127.0.0.1:4000/healthz', r=>process.exit(r.statusCode===200?0:1)).on('error', ()=>process.exit(1))" 2>/dev/null; then
        log_success "Health check passed!"
        break
    fi

    if [ $i -eq $HEALTH_CHECK_RETRIES ]; then
        log_error "Health check failed after rollback!"
        log_error "Manual intervention required!"
        docker compose logs --tail=50 api
        exit 1
    fi

    sleep $HEALTH_CHECK_DELAY
done

log_success "==================================="
log_success "Rollback completed successfully!"
log_success "==================================="
log_info "Reverted to commit: $LAST_COMMIT"
log_info ""
log_info "Recent logs:"
docker compose logs --tail=30 api

echo ""
log_warning "Note: This rollback is temporary. The next deployment will move forward again."
log_warning "If you want to permanently revert, reset the main branch in your repository."
