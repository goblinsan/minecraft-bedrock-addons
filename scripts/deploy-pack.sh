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

# --- Read pack UUID and version from manifest ---
MANIFEST="${PACK_DIR}/manifest.json"
PACK_UUID=$(jq -r '.header.uuid' "${MANIFEST}")
PACK_VERSION=$(jq -c '.header.version' "${MANIFEST}")

echo "==> Deploying ${PACK_NAME} (UUID: ${PACK_UUID}) to ${ENV_NAME}..."

# --- Back up existing pack in the container ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${REPO_ROOT}/logs/backups/${PACK_NAME}-${TIMESTAMP}"
mkdir -p "${REPO_ROOT}/logs/backups"

if docker exec "${CONTAINER_NAME}" test -d "${BEHAVIOR_PACK_DEST}/${PACK_NAME}" 2>/dev/null; then
  echo "==> Backing up existing pack to ${BACKUP_DIR}..."
  mkdir -p "${BACKUP_DIR}"
  docker cp "${CONTAINER_NAME}:${BEHAVIOR_PACK_DEST}/${PACK_NAME}" "${BACKUP_DIR}/"
fi

# --- Copy pack into the container ---
echo "==> Copying pack files to ${CONTAINER_NAME}:${BEHAVIOR_PACK_DEST}/${PACK_NAME}..."
docker cp "${PACK_DIR}/." "${CONTAINER_NAME}:${BEHAVIOR_PACK_DEST}/${PACK_NAME}"

# --- Update world_behavior_packs.json ---
WORLD_BP_JSON="${HOST_WORLD_PATH}/world_behavior_packs.json"

if [[ -f "${WORLD_BP_JSON}" ]]; then
  # Add or update the pack entry
  UPDATED=$(jq --arg uuid "${PACK_UUID}" --argjson version "${PACK_VERSION}" '
    if any(.[]; .pack_id == $uuid)
    then map(if .pack_id == $uuid then .version = $version else . end)
    else . + [{"pack_id": $uuid, "version": $version}]
    end
  ' "${WORLD_BP_JSON}")
  echo "${UPDATED}" > "${WORLD_BP_JSON}"
  echo " OK: Updated world_behavior_packs.json"
else
  echo "[{\"pack_id\": \"${PACK_UUID}\", \"version\": ${PACK_VERSION}}]" > "${WORLD_BP_JSON}"
  echo " OK: Created world_behavior_packs.json"
fi

# --- Restart the container ---
echo "==> Restarting ${CONTAINER_NAME}..."
docker restart "${CONTAINER_NAME}"

# --- Log the deployment ---
mkdir -p "${REPO_ROOT}/logs"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY pack=${PACK_NAME} env=${ENV_NAME} uuid=${PACK_UUID} status=SUCCESS" >> "${LOG_FILE}"

echo "DONE: ${PACK_NAME} deployed to ${ENV_NAME}"
