#!/usr/bin/env bash
# backup.sh — Daily mongodump with gzip, 7 daily + 4 weekly rotation
# Intended to run via cron: 0 2 * * * /srv/mongodb/backup.sh >> /var/log/mongodb-backup.log 2>&1

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
MONGO_ROOT_USER="${MONGO_ROOT_USER:?Set MONGO_ROOT_USER}"
MONGO_ROOT_PASSWORD="${MONGO_ROOT_PASSWORD:?Set MONGO_ROOT_PASSWORD}"
MONGO_DB="${MONGO_DB:-nexa_prod}"
CONTAINER="${CONTAINER:-nexa-mongodb}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/mongodb}"
DAILY_RETAIN=7
WEEKLY_RETAIN=4

DATE=$(date +%Y-%m-%d_%H%M)
DAY_OF_WEEK=$(date +%u)  # 1=Monday, 7=Sunday

DAILY_DIR="${BACKUP_DIR}/daily"
WEEKLY_DIR="${BACKUP_DIR}/weekly"

mkdir -p "$DAILY_DIR" "$WEEKLY_DIR"

echo "[$(date -Iseconds)] Starting backup of ${MONGO_DB}..."

# ── Dump ────────────────────────────────────────────────────────────────────
DUMP_FILE="${DAILY_DIR}/${MONGO_DB}_${DATE}.gz"

docker exec "$CONTAINER" mongodump \
  -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --db "$MONGO_DB" \
  --gzip --archive \
  > "$DUMP_FILE"

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
echo "[$(date -Iseconds)] Backup complete: ${DUMP_FILE} (${DUMP_SIZE})"

# ── Weekly copy (Sundays) ──────────────────────────────────────────────────
if [ "$DAY_OF_WEEK" -eq 7 ]; then
  cp "$DUMP_FILE" "${WEEKLY_DIR}/${MONGO_DB}_weekly_${DATE}.gz"
  echo "[$(date -Iseconds)] Weekly backup saved"
fi

# ── Rotate daily (keep last N) ─────────────────────────────────────────────
ls -1t "${DAILY_DIR}"/*.gz 2>/dev/null | tail -n +$((DAILY_RETAIN + 1)) | xargs -r rm -f
echo "[$(date -Iseconds)] Daily rotation: keeping last ${DAILY_RETAIN}"

# ── Rotate weekly (keep last N) ────────────────────────────────────────────
ls -1t "${WEEKLY_DIR}"/*.gz 2>/dev/null | tail -n +$((WEEKLY_RETAIN + 1)) | xargs -r rm -f
echo "[$(date -Iseconds)] Weekly rotation: keeping last ${WEEKLY_RETAIN}"

echo "[$(date -Iseconds)] Backup job finished"
