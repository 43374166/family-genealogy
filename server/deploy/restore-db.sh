#!/usr/bin/env bash
set -euo pipefail

DB_NAME="${DB_NAME:-familytree}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/familytree}"
MODE="${1:-verify}"
if [[ "${MODE}" == "--production" ]]; then
  FILE="${2:-${BACKUP_DIR}/latest.sql.gz}"
else
  FILE="${1:-${BACKUP_DIR}/latest.sql.gz}"
fi
SCRATCH_DB="familytree_restore_check"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi
if [[ ! -f "${FILE}" ]]; then
  echo "backup file not found: ${FILE}" >&2
  exit 1
fi
if ! gzip -t "${FILE}"; then
  echo "backup is not a valid gzip file: ${FILE}" >&2
  exit 1
fi

if [[ "${MODE}" == "--production" ]]; then
  if [[ "${CONFIRM_RESTORE:-}" != "YES" ]]; then
    echo "refusing destructive restore; set CONFIRM_RESTORE=YES" >&2
    exit 1
  fi
  echo "stopping API and taking a safety backup"
  systemctl stop familytree-api
  restart_api() { systemctl start familytree-api; }
  trap restart_api EXIT
  /usr/local/sbin/familytree-backup
  echo "restoring ${FILE} into ${DB_NAME}"
  gunzip -c "${FILE}" | mysql --user=root "${DB_NAME}"
  echo "production restore complete"
  systemctl start familytree-api
  trap - EXIT
  exit 0
fi

echo "verifying ${FILE} in ${SCRATCH_DB}"
mysql --user=root -e "DROP DATABASE IF EXISTS \`${SCRATCH_DB}\`; CREATE DATABASE \`${SCRATCH_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
gunzip -c "${FILE}" | mysql --user=root "${SCRATCH_DB}"

echo "row counts:"
mysql --user=root -N -e "
  SELECT 'persons', COUNT(*) FROM \`${SCRATCH_DB}\`.persons
  UNION ALL SELECT 'relationships', COUNT(*) FROM \`${SCRATCH_DB}\`.parent_child_relationships
  UNION ALL SELECT 'users', COUNT(*) FROM \`${SCRATCH_DB}\`.users
  UNION ALL SELECT 'audit_logs', COUNT(*) FROM \`${SCRATCH_DB}\`.audit_logs;"

mysql --user=root -e "DROP DATABASE \`${SCRATCH_DB}\`;"
echo "restore verification complete"

cat <<EOF

To restore production (destructive, takes a safety backup first):
  CONFIRM_RESTORE=YES /usr/local/sbin/familytree-restore --production "${FILE}"
EOF
