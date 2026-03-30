#!/usr/bin/env bash
# deploy-pack.sh — Deploy a single pack to a target environment.
#
# Usage: bash scripts/deploy-pack.sh <pack-name> <environment>
# Example: bash scripts/deploy-pack.sh days-survived test
#          bash scripts/deploy-pack.sh days-survived prod
#
# Reads configuration from environments/<environment>.env

set -euo pipefail

PACK_NAME="${1:-}"
ENV_NAME="${2:-}"

if [[ -z "${PACK_NAME}" || -z "${ENV_NAME}" ]]; then
  echo "ERROR: pack name and environment arguments are required."
  echo "Usage: bash scripts/deploy-pack.sh <pack-name> <environment>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACK_DIR="${REPO_ROOT}/packs/${PACK_NAME}"
ENV_FILE="${REPO_ROOT}/environments/${ENV_NAME}.env"
LOG_FILE="${REPO_ROOT}/logs/deployments.log"

# --- Load environment config ---
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: Environment config not found: ${ENV_FILE}"
  echo "Copy environments/${ENV_NAME}.example.env to environments/${ENV_NAME}.env and fill in your values."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

if [[ ! -d "${PACK_DIR}" ]]; then
  echo "ERROR: Pack directory not found: ${PACK_DIR}"
  exit 1
fi

# --- Validate before deploying ---
echo "==> Validating ${PACK_NAME}..."
bash "${SCRIPT_DIR}/validate-pack.sh" "${PACK_DIR}"

# --- Read pack UUID, version, and module type from manifest ---
MANIFEST="${PACK_DIR}/manifest.json"
PACK_UUID=$(jq -r '.header.uuid' "${MANIFEST}")
PACK_VERSION=$(jq -c '.header.version' "${MANIFEST}")
MODULE_TYPE=$(jq -r '.modules[0].type // "data"' "${MANIFEST}")

# Module type "resources" indicates a resource pack; all other types (data,
# script, world_template, etc.) are treated as behavior packs.
if [[ "${MODULE_TYPE}" == "resources" ]]; then
  PACK_KIND="resource"
  PACK_DEST="${RESOURCE_PACK_DEST}"
else
  PACK_KIND="behavior"
  PACK_DEST="${BEHAVIOR_PACK_DEST}"
fi

echo "==> Deploying ${PACK_NAME} (${PACK_KIND}, UUID: ${PACK_UUID}) to ${ENV_NAME}..."

# --- Production deployment guard ---
# Require explicit confirmation when targeting production, unless the caller has
# already confirmed (e.g. promote-to-prod.sh sets SKIP_PROD_CONFIRM=1).
if [[ "${ENV_NAME}" == "prod" ]] && [[ "${SKIP_PROD_CONFIRM:-0}" != "1" ]]; then
  echo ""
  echo "WARNING: You are about to deploy to PRODUCTION."
  echo "  Pack:       ${PACK_NAME}"
  echo "  Container:  ${CONTAINER_NAME}"
  echo ""
  echo "Use 'bash scripts/promote-to-prod.sh ${PACK_NAME}' for the full test-verified"
  echo "promotion workflow."
  echo ""
  read -rp "Type 'yes' to confirm direct production deployment: " _PROD_CONFIRM
  if [[ "${_PROD_CONFIRM}" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# --- Back up existing pack in the container ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${REPO_ROOT}/logs/backups/${PACK_NAME}-${TIMESTAMP}"
mkdir -p "${REPO_ROOT}/logs/backups"

if docker exec "${CONTAINER_NAME}" test -d "${PACK_DEST}/${PACK_NAME}" 2>/dev/null; then
  echo "==> Backing up existing pack to ${BACKUP_DIR}..."
  mkdir -p "${BACKUP_DIR}"
  docker cp "${CONTAINER_NAME}:${PACK_DEST}/${PACK_NAME}" "${BACKUP_DIR}/"
fi

# --- Copy pack into the container ---
echo "==> Copying pack files to ${CONTAINER_NAME}:${PACK_DEST}/${PACK_NAME}..."
docker cp "${PACK_DIR}/." "${CONTAINER_NAME}:${PACK_DEST}/${PACK_NAME}"

# --- Register the pack in the world's pack JSON ---
bash "${SCRIPT_DIR}/register-world-packs.sh" "${PACK_UUID}" "${PACK_VERSION}" "${PACK_KIND}" "${ENV_NAME}"

# --- Restart the container ---
echo "==> Restarting ${CONTAINER_NAME}..."
docker restart "${CONTAINER_NAME}"

# --- Log the deployment ---
mkdir -p "${REPO_ROOT}/logs"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY pack=${PACK_NAME} env=${ENV_NAME} uuid=${PACK_UUID} backup=${BACKUP_DIR} status=SUCCESS" >> "${LOG_FILE}"

echo "DONE: ${PACK_NAME} deployed to ${ENV_NAME}"
