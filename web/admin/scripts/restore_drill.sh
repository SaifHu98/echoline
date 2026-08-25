#!/usr/bin/env bash
# ====================================================================
# Monthly restore drill — restores backup to staging DB and verifies
# Usage: bash restore_drill.sh [backup_file]
# Should run on staging environment, NOT production
# ====================================================================

set -euo pipefail

BACKUP_FILE="${1:-}"
STAGING_DB="${STAGING_DB:-echoline_staging}"

if [[ -z "${BACKUP_FILE}" ]]; then
  # Pick most recent backup
  BACKUP_FILE="$(ls -1t /var/backups/echoline/echoline-*.sql.gz 2>/dev/null | head -1 || true)"
fi

if [[ -z "${BACKUP_FILE}" || ! -f "${BACKUP_FILE}" ]]; then
  echo "ERROR: No backup file found"
  exit 1
fi

: "${DB_HOST:?Need DB_HOST}"
: "${DB_USER:?Need DB_USER}"
: "${DB_NAME:=${STAGING_DB}}"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] === Restore drill start ==="
echo "Backup file: ${BACKUP_FILE}"
echo "Staging DB:  ${DB_NAME}"

# 1) Verify checksum
echo "Step 1: Verify checksum"
if [[ -f "${BACKUP_FILE}.sha256" ]]; then
  if ! sha256sum -c "${BACKUP_FILE}.sha256" >/dev/null 2>&1; then
    echo "ERROR: Checksum mismatch"
    exit 1
  fi
  echo "  ✓ Checksum OK"
else
  echo "  WARN: no checksum file"
fi

# 2) Create staging DB if missing
echo "Step 2: Prepare staging DB"
mysql --host="${DB_HOST}" --user="${DB_USER}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`" 2>&1 | grep -v "Using a password" || true

# 3) Restore
echo "Step 3: Restore from backup"
if ! gunzip < "${BACKUP_FILE}" | mysql --host="${DB_HOST}" --user="${DB_USER}" "${DB_NAME}" 2>>/tmp/restore_err.log; then
  echo "ERROR: Restore failed"
  cat /tmp/restore_err.log
  exit 1
fi
echo "  ✓ Restore OK"

# 4) Verify integrity
echo "Step 4: Verify integrity"
TABLES=$(mysql --host="${DB_HOST}" --user="${DB_USER}" "${DB_NAME}" -BNe "SHOW TABLES" 2>/dev/null)
if [[ -z "${TABLES}" ]]; then
  echo "ERROR: No tables found after restore"
  exit 1
fi
echo "  ✓ $(echo "${TABLES}" | wc -l) tables present"

# 5) Sanity checks
echo "Step 5: Sanity checks"
ADMIN_COUNT=$(mysql --host="${DB_HOST}" --user="${DB_USER}" "${DB_NAME}" -BNe "SELECT COUNT(*) FROM admins" 2>/dev/null || echo "0")
SHOP_COUNT=$(mysql --host="${DB_HOST}" --user="${DB_USER}" "${DB_NAME}" -BNe "SELECT COUNT(*) FROM shop_items" 2>/dev/null || echo "0")
echo "  Admins: ${ADMIN_COUNT}"
echo "  Shop items: ${SHOP_COUNT}"

if [[ "${ADMIN_COUNT}" == "0" ]]; then
  echo "ERROR: No admins in restored DB"
  exit 1
fi

# 6) Test queries that production uses
echo "Step 6: Run representative queries"
mysql --host="${DB_HOST}" --user="${DB_USER}" "${DB_NAME}" -e "
  SELECT COUNT(*) AS shop_active FROM shop_items WHERE is_active = 1;
  SELECT COUNT(*) AS events_active FROM events WHERE is_active = 1;
  SELECT COUNT(*) AS audit_recent FROM admin_audit_log WHERE occurred_at > DATE_SUB(NOW(), INTERVAL 7 DAY);
" 2>/dev/null

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] === Restore drill SUCCESS ==="