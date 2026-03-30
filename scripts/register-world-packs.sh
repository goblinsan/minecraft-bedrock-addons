#!/usr/bin/env bash
# register-world-packs.sh — Safely add or update a pack entry in a world's
# world_behavior_packs.json or world_resource_packs.json.
#
# Usage:
#   bash scripts/register-world-packs.sh <pack-uuid> <version-json> <pack-type> <environment>
#
# Arguments:
#   pack-uuid     — The header UUID from the pack's manifest.json
#   version-json  — The version array as a JSON literal, e.g. [1,0,0]
#   pack-type     — "behavior" or "resource"
#   environment   — Environment name (e.g. test, prod); resolves to environments/<env>.env
#
# Examples:
#   bash scripts/register-world-packs.sh "aaaaaaaa-..." "[1,0,0]" behavior test
#   bash scripts/register-world-packs.sh "bbbbbbbb-..." "[1,0,0]" resource prod
#
# The script writes directly to the host-mounted world folder defined in the
# environment config (HOST_WORLD_PATH). The Bedrock server container must be
# restarted separately for the change to take effect.

set -euo pipefail

PACK_UUID="${1:-}"
PACK_VERSION="${2:-}"
PACK_TYPE="${3:-}"
ENV_NAME="${4:-}"

# --- Validate arguments ---
if [[ -z "${PACK_UUID}" || -z "${PACK_VERSION}" || -z "${PACK_TYPE}" || -z "${ENV_NAME}" ]]; then
  echo "ERROR: all arguments are required."
  echo "Usage: bash scripts/register-world-packs.sh <pack-uuid> <version-json> <pack-type> <environment>"
  echo "  pack-type must be 'behavior' or 'resource'"
  exit 1
fi

if [[ "${PACK_TYPE}" != "behavior" && "${PACK_TYPE}" != "resource" ]]; then
  echo "ERROR: pack-type must be 'behavior' or 'resource', got: ${PACK_TYPE}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/environments/${ENV_NAME}.env"

# --- Load environment config ---
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: Environment config not found: ${ENV_FILE}"
  echo "Copy environments/${ENV_NAME}.example.env to environments/${ENV_NAME}.env and fill in your values."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

# --- Resolve target JSON file ---
if [[ "${PACK_TYPE}" == "behavior" ]]; then
  WORLD_PACKS_JSON="${HOST_WORLD_PATH}/world_behavior_packs.json"
else
  WORLD_PACKS_JSON="${HOST_WORLD_PATH}/world_resource_packs.json"
fi

echo "==> Registering ${PACK_TYPE} pack ${PACK_UUID} (version ${PACK_VERSION}) in ${WORLD_PACKS_JSON}..."

# --- Update or create the JSON file ---
if [[ -f "${WORLD_PACKS_JSON}" ]]; then
  UPDATED=$(jq --arg uuid "${PACK_UUID}" --argjson version "${PACK_VERSION}" '
    if any(.[]; .pack_id == $uuid)
    then map(if .pack_id == $uuid then .version = $version else . end)
    else . + [{"pack_id": $uuid, "version": $version}]
    end
  ' "${WORLD_PACKS_JSON}") || { echo "ERROR: jq failed to process ${WORLD_PACKS_JSON}"; exit 1; }
  if [[ -z "${UPDATED}" ]]; then
    echo "ERROR: jq produced empty output for ${WORLD_PACKS_JSON}"
    exit 1
  fi
  echo "${UPDATED}" > "${WORLD_PACKS_JSON}"
  echo " OK: Updated ${WORLD_PACKS_JSON}"
else
  mkdir -p "$(dirname "${WORLD_PACKS_JSON}")"
  printf '[{"pack_id": "%s", "version": %s}]\n' "${PACK_UUID}" "${PACK_VERSION}" > "${WORLD_PACKS_JSON}"
  echo " OK: Created ${WORLD_PACKS_JSON}"
fi
