#!/usr/bin/env bash
# setup.sh — Provision a fresh Linode for hosting MongoDB
#
# What it does:
#   1. Updates packages
#   2. Installs Docker + Docker Compose
#   3. Configures UFW firewall (SSH + MongoDB from app server only)
#   4. Creates directory structure
#   5. Sets up backup cron job
#
# Usage: ssh root@<db-server-ip> 'bash -s' < infrastructure/db-server/setup.sh

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
APP_SERVER_IP="${APP_SERVER_IP:-198.58.111.243}"
MONGODB_PORT=27017

echo "============================================"
echo "  Nexa DB Server Setup"
echo "  App Server IP: ${APP_SERVER_IP}"
echo "============================================"

# ── 1. System updates ──────────────────────────────────────────────────────
echo ""
echo "==> Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq

# ── 2. Install Docker ──────────────────────────────────────────────────────
echo ""
echo "==> Installing Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo "    Docker installed: $(docker --version)"
else
  echo "    Docker already installed: $(docker --version)"
fi

# ── 3. Firewall (UFW) ─────────────────────────────────────────────────────
echo ""
echo "==> Configuring firewall..."
apt-get install -y -qq ufw

ufw default deny incoming
ufw default allow outgoing

# SSH from anywhere (so you don't lock yourself out)
ufw allow 22/tcp

# MongoDB only from the app server
ufw allow from "$APP_SERVER_IP" to any port "$MONGODB_PORT" proto tcp

# Enable without prompt
echo "y" | ufw enable
ufw status verbose

# ── 4. Directory structure ─────────────────────────────────────────────────
echo ""
echo "==> Creating directory structure..."
mkdir -p /srv/mongodb
mkdir -p /srv/backups/mongodb/{daily,weekly}

# ── 5. Backup cron ────────────────────────────────────────────────────────
echo ""
echo "==> Setting up backup cron job..."

# Copy backup script (will be deployed separately via scp)
# Cron entry: run backup daily at 2 AM
CRON_LINE="0 2 * * * /srv/mongodb/backup.sh >> /var/log/mongodb-backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v 'mongodb/backup.sh'; echo "$CRON_LINE") | crontab -
echo "    Cron installed: ${CRON_LINE}"

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Setup complete!"
echo ""
echo "  Next steps:"
echo "    1. scp docker-compose.yml root@<this-ip>:/srv/mongodb/"
echo "    2. scp backup.sh root@<this-ip>:/srv/mongodb/"
echo "    3. Create .env at /srv/mongodb/.env with:"
echo "         MONGO_ROOT_USER=admin"
echo "         MONGO_ROOT_PASSWORD=<strong-password>"
echo "         MONGO_APP_USER=nexa_app"
echo "         MONGO_APP_PASSWORD=<strong-password>"
echo "         MONGO_DB=nexa_prod"
echo "    4. cd /srv/mongodb && docker compose up -d"
echo "    5. Run init-replica-set.sh"
echo "============================================"
