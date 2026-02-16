#!/usr/bin/env bash
# restore.sh — Restore MongoDB from backup archive or mongodump directory
#
# Usage (from gzip archive — daily/weekly backups):
#   ./restore.sh /srv/backups/mongodb/daily/nexa_prod_2025-01-15_0200.gz
#
# Usage (from mongodump directory — Atlas migration):
#   ./restore.sh /tmp/atlas-backup/nexa_prod

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
MONGO_ROOT_USER="${MONGO_ROOT_USER:?Set MONGO_ROOT_USER}"
MONGO_ROOT_PASSWORD="${MONGO_ROOT_PASSWORD:?Set MONGO_ROOT_PASSWORD}"
MONGO_DB="${MONGO_DB:-nexa_prod}"
CONTAINER="${CONTAINER:-nexa-mongodb}"

BACKUP_PATH="${1:?Usage: $0 <backup-file.gz | dump-directory>}"

if [ ! -e "$BACKUP_PATH" ]; then
  echo "Error: ${BACKUP_PATH} does not exist" >&2
  exit 1
fi

echo "==> Restoring ${MONGO_DB} from: ${BACKUP_PATH}"
echo "    WARNING: This will overwrite existing data in '${MONGO_DB}'"
read -rp "    Continue? (y/N) " confirm
if [[ "$confirm" != [yY] ]]; then
  echo "Aborted."
  exit 0
fi

if [ -f "$BACKUP_PATH" ]; then
  # ── Restore from gzip archive (daily/weekly backups) ────────────────────
  echo "==> Restoring from gzip archive..."
  docker exec -i "$CONTAINER" mongorestore \
    -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --db "$MONGO_DB" \
    --gzip --archive \
    --drop \
    < "$BACKUP_PATH"

elif [ -d "$BACKUP_PATH" ]; then
  # ── Restore from mongodump directory (Atlas migration) ──────────────────
  echo "==> Restoring from dump directory..."
  # Copy dump into container, then restore
  docker cp "$BACKUP_PATH" "${CONTAINER}:/tmp/restore_dump"
  docker exec "$CONTAINER" mongorestore \
    -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --db "$MONGO_DB" \
    --drop \
    /tmp/restore_dump
  docker exec "$CONTAINER" rm -rf /tmp/restore_dump
else
  echo "Error: ${BACKUP_PATH} is not a file or directory" >&2
  exit 1
fi

echo ""
echo "==> Restore complete. Verifying..."

# ── Verify ──────────────────────────────────────────────────────────────────
docker exec "$CONTAINER" mongosh -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin "$MONGO_DB" --eval '
  const colls = db.getCollectionNames().sort();
  print("Collections: " + colls.join(", "));
  colls.forEach(c => {
    const count = db.getCollection(c).countDocuments();
    print("  " + c + ": " + count + " documents");
  });
'

echo ""
echo "==> Done! Verify the counts above match your expectations."
