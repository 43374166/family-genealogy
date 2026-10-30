#!/usr/bin/env bash
set -euo pipefail
umask 077

DB_NAME="${DB_NAME:-familytree}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/familytree}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
TARGET="${BACKUP_DIR}/familytree-${STAMP}.sql.gz"
TMP="${TARGET}.tmp"

mkdir -p "${BACKUP_DIR}"

exec 9>/run/lock/familytree-backup.lock
if ! flock -n 9; then
  echo "backup already running" >&2
  exit 0
fi

cleanup() {
  rm -f "${TMP}"
}
trap cleanup EXIT

mysqldump \
  --user=root \
  --single-transaction \
  --quick \
  --routines \
  --triggers \
  --events \
  --set-gtid-purged=OFF \
  --default-character-set=utf8mb4 \
  "${DB_NAME}" | gzip -9 > "${TMP}"

gzip -t "${TMP}"
mv "${TMP}" "${TARGET}"
sha256sum "${TARGET}" > "${TARGET}.sha256"
ln -sfn "$(basename "${TARGET}")" "${BACKUP_DIR}/latest.sql.gz"
ln -sfn "$(basename "${TARGET}").sha256" "${BACKUP_DIR}/latest.sql.gz.sha256"

find "${BACKUP_DIR}" \
  -maxdepth 1 \
  -type f \
  -name 'familytree-*.sql.gz' \
  -mtime "+${RETENTION_DAYS}" \
  -delete
find "${BACKUP_DIR}" \
  -maxdepth 1 \
  -type f \
  -name 'familytree-*.sql.gz.sha256' \
  -mtime "+${RETENTION_DAYS}" \
  -delete

echo "backup complete: ${TARGET}"
ls -lh "${TARGET}"
