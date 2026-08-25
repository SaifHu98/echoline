#!/usr/bin/env bash
# ====================================================================
# Daily backup script for ECHO//LINE
# Usage: bash backup.sh [destination_dir]
# Runs mysqldump → compress → off-site copy
# ====================================================================

set -euo pipefail

DEST_DIR="${1:-/var/backups/echoline}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="${DEST_DIR}/echoline-${TIMESTAMP}.sql.gz"
LOG_FILE="${DEST_DIR}/backup.log"

mkdir -p "${DEST_DIR}"

# Read DB config from env
: "${DB_HOST:?Need DB_HOST}"
: "${DB_USER:?Need DB_USER}"
: "${DB_NAME:?Need DB_NAME}"
# DB_PASS should be in env, not command line — use --defaults-file or my_login_path

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "${LOG_FILE}"
}

log "=== Backup start ==="

# 1) mysqldump → gzip
if ! mysqldump \
    --host="${DB_HOST}" \
    --user="${DB_USER}" \
    --single-transaction \
    --quick \
    --lock-tables=false \
    --routines \
    --triggers \
    --events \
    --set-gtid-purged=OFF \
    --default-character-set=utf8mb4 \
    "${DB_NAME}" 2>>"${LOG_FILE}" | gzip > "${BACKUP_FILE}"; then
  log "ERROR: mysqldump failed"
  exit 1
fi

# 2) Checksum
sha256sum "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"
log "Backup created: ${BACKUP_FILE} ($(stat -c %s "${BACKUP_FILE}") bytes)"

# 3) Off-site copy (s3) — only if S3_BUCKET configured
if [[ -n "${S3_BUCKET:-}" ]]; then
  if command -v aws >/dev/null 2>&1; then
    if aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/echoline-db/${TIMESTAMP}.sql.gz" --sse AES256 >>"${LOG_FILE}" 2>&1; then
      log "Off-site copy OK"
    else
      log "ERROR: Off-site copy failed"
    fi
  fi
fi

# 4) Retention: delete backups older than 30 days
find "${DEST_DIR}" -name "echoline-*.sql.gz" -mtime +30 -delete 2>/dev/null || true
find "${DEST_DIR}" -name "echoline-*.sql.gz.sha256" -mtime +30 -delete 2>/dev/null || true

log "=== Backup complete ==="