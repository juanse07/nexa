#!/usr/bin/env bash
# init-replica-set.sh — Initialize single-node replica set and create app user
# Run once after first `docker compose up -d`
#
# Usage: ssh root@<db-server-ip> 'bash -s' < infrastructure/db-server/init-replica-set.sh

set -euo pipefail

# ── Config (override via env vars) ──────────────────────────────────────────
MONGO_ROOT_USER="${MONGO_ROOT_USER:?Set MONGO_ROOT_USER}"
MONGO_ROOT_PASSWORD="${MONGO_ROOT_PASSWORD:?Set MONGO_ROOT_PASSWORD}"
MONGO_APP_USER="${MONGO_APP_USER:-nexa_app}"
MONGO_APP_PASSWORD="${MONGO_APP_PASSWORD:?Set MONGO_APP_PASSWORD}"
MONGO_DB="${MONGO_DB:-nexa_prod}"
CONTAINER="${CONTAINER:-nexa-mongodb}"

echo "==> Waiting for MongoDB to be ready..."
until docker exec "$CONTAINER" mongosh -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin --eval "db.adminCommand('ping')" &>/dev/null; do
  sleep 2
done
echo "==> MongoDB is ready"

echo "==> Initiating replica set rs0..."
docker exec "$CONTAINER" mongosh -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin --eval '
  rs.initiate({
    _id: "rs0",
    members: [{ _id: 0, host: "localhost:27017" }]
  });
'

echo "==> Waiting for replica set to elect primary..."
sleep 5

echo "==> Creating app user '${MONGO_APP_USER}' on database '${MONGO_DB}'..."
docker exec "$CONTAINER" mongosh -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin "$MONGO_DB" --eval "
  db.createUser({
    user: '${MONGO_APP_USER}',
    pwd: '${MONGO_APP_PASSWORD}',
    roles: [{ role: 'readWrite', db: '${MONGO_DB}' }]
  });
"

echo "==> Verifying replica set status..."
docker exec "$CONTAINER" mongosh -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin --eval "rs.status().ok"

echo ""
echo "==> Done! Connection string for the app:"
echo "    mongodb://${MONGO_APP_USER}:<password>@<db-server-ip>:27017/?replicaSet=rs0&authSource=${MONGO_DB}"
