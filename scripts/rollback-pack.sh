#!/usr/bin/env bash
# rollback-pack.sh — Restore a pack to its previous version and re-deploy.
#
# Usage: bash scripts/rollback-pack.sh <pack-name> <environment> [backup-timestamp]
# Examples:
#   bash scripts/rollback-pack.sh days-survived prod              # uses latest backup
#   bash scripts/rollback-pack.sh days-survived prod 20240115_142301
#
# Backups are created automatically by deploy-pack.sh and stored under:
#   logs/backups/<pack-name>-<timestamp>/
#
# The rollback:
#  1. Locates the target backup
#  2. Restores the backup files to packs/<pack-name>/
#  3. Re-deploys via deploy-pack.sh (which re-validates and logs the event)
#  4. Appends a ROLLBACK entry to logs/deployments.log

set -euo pipefail

PACK_NAME="${1:-}"
ENV_NAME="${2:-}"
BACKUP_TIMESTAMP="${3:-}"

if [[ -z "${PACK_NAME}" || -z "${ENV_NAME}" ]]; then
  echo "ERROR: pack name and environment arguments are required."
  echo "Usage: bash scripts/rollback-pack.sh <pack-name> <environment> [backup-timestamp]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUPS_DIR="${REPO_ROOT}/logs/backups"
PACK_DIR="${REPO_ROOT}/packs/${PACK_NAME}"
LOG_FILE="${REPO_ROOT}/logs/deployments.log"

# --- Validate pack name to prevent path traversal ---
if [[ ! "${PACK_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERROR: Invalid pack name '${PACK_NAME}'. Use only alphanumeric characters, hyphens, and underscores."
  exit 1
fi

# --- Locate available backups ---
if [[ -z "${BACKUP_TIMESTAMP}" ]]; then
  # Use the most recent backup for this pack
  BACKUP_PATH=$(find "${BACKUPS_DIR}" -maxdepth 1 -type d -name "${PACK_NAME}-*" 2>/dev/null \
    | sort | tail -1 || true)

  if [[ -z "${BACKUP_PATH}" ]]; then
    echo "ERROR: No backups found for '${PACK_NAME}' under ${BACKUPS_DIR}"
    echo "       Backups are created automatically on each deployment."
    exit 1
  fi
else
  BACKUP_PATH="${BACKUPS_DIR}/${PACK_NAME}-${BACKUP_TIMESTAMP}"
  if [[ ! -d "${BACKUP_PATH}" ]]; then
    echo "ERROR: Backup not found: ${BACKUP_PATH}"
    echo "Available backups:"
    find "${BACKUPS_DIR}" -maxdepth 1 -type d -name "${PACK_NAME}-*" 2>/dev/null | sort || true
    exit 1
  fi
fi

# deploy-pack.sh copies '<container>:<dest>/<pack-name>' into the backup dir,
# which docker cp places at '<backup-dir>/<pack-name>/'.
BACKUP_PACK_DIR="${BACKUP_PATH}/${PACK_NAME}"
if [[ ! -d "${BACKUP_PACK_DIR}" ]]; then
  echo "ERROR: Backup pack directory not found: ${BACKUP_PACK_DIR}"
  echo "       The backup at ${BACKUP_PATH} may be incomplete."
  exit 1
fi

echo "==> Rolling back '${PACK_NAME}' on '${ENV_NAME}' using backup:"
echo "    ${BACKUP_PATH}"
echo ""

# --- Require confirmation ---
read -rp "Type 'yes' to confirm rollback: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

echo ""

# --- Restore backup files to the local pack directory ---
echo "==> Restoring backup to ${PACK_DIR}..."
# Remove current pack contents and replace with backup
rm -rf "${PACK_DIR:?}/"*
cp -r "${BACKUP_PACK_DIR}/." "${PACK_DIR}/"
echo " OK: Restored from ${BACKUP_PACK_DIR}"

echo ""

# --- Re-deploy to the target environment ---
echo "==> Re-deploying ${PACK_NAME} to ${ENV_NAME} from restored backup..."
# Bypass the interactive prod guard since the user already confirmed above
SKIP_PROD_CONFIRM=1 bash "${SCRIPT_DIR}/deploy-pack.sh" "${PACK_NAME}" "${ENV_NAME}"

# --- Log the rollback event ---
mkdir -p "${REPO_ROOT}/logs"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ROLLBACK pack=${PACK_NAME} env=${ENV_NAME} from=${BACKUP_PATH} status=SUCCESS" >> "${LOG_FILE}"

echo ""
echo "DONE: ${PACK_NAME} rolled back on ${ENV_NAME}."
