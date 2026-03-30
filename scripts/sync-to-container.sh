#!/usr/bin/env bash
# sync-to-container.sh — Copy a pack directly into a running Docker container.
#
# This is a lightweight alternative to deploy-pack.sh for fast iteration during
# development. It copies files without restarting the container or updating
# world_behavior_packs.json. Useful when the pack is already registered and you
# only need to push updated function files.
#
# Usage: bash scripts/sync-to-container.sh <pack-name> <environment>
# Example: bash scripts/sync-to-container.sh days-survived test

set -euo pipefail

PACK_NAME="${1:-}"
ENV_NAME="${2:-}"

if [[ -z "${PACK_NAME}" || -z "${ENV_NAME}" ]]; then
  echo "ERROR: pack name and environment arguments are required."
  echo "Usage: bash scripts/sync-to-container.sh <pack-name> <environment>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACK_DIR="${REPO_ROOT}/packs/${PACK_NAME}"
ENV_FILE="${REPO_ROOT}/environments/${ENV_NAME}.env"

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

echo "==> Syncing ${PACK_NAME} → ${CONTAINER_NAME}:${BEHAVIOR_PACK_DEST}/${PACK_NAME}..."

docker cp "${PACK_DIR}/." "${CONTAINER_NAME}:${BEHAVIOR_PACK_DEST}/${PACK_NAME}"

echo "DONE: Files synced. Run '/reload' in-game or restart the container to apply changes."
