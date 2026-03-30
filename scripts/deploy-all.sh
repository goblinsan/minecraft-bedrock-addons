#!/usr/bin/env bash
# deploy-all.sh — Deploy every pack under packs/ to the target environment.
#
# Usage: bash scripts/deploy-all.sh <environment>
# Example: bash scripts/deploy-all.sh test

set -euo pipefail

ENV_NAME="${1:-}"

if [[ -z "${ENV_NAME}" ]]; then
  echo "ERROR: environment argument is required."
  echo "Usage: bash scripts/deploy-all.sh <environment>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKS_DIR="${REPO_ROOT}/packs"
ENV_FILE="${REPO_ROOT}/environments/${ENV_NAME}.env"

# Load environment config to pick up ENABLED_PACKS (if set)
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

ENABLED_PACKS="${ENABLED_PACKS:-}"

DEPLOYED=0
FAILED=0

echo "==> Deploying all packs to ${ENV_NAME}..."

for pack_dir in "${PACKS_DIR}"/*/; do
  pack_name="$(basename "${pack_dir}")"

  # Skip .gitkeep or any non-pack entries
  if [[ ! -f "${pack_dir}/manifest.json" ]]; then
    echo "SKIP: ${pack_name} (no manifest.json)"
    continue
  fi

  # Skip packs not in ENABLED_PACKS when the variable is set.
  # Pack names are directory names and cannot contain spaces, so word-splitting
  # ${ENABLED_PACKS} on whitespace is safe here.
  if [[ -n "${ENABLED_PACKS}" ]]; then
    enabled=false
    for enabled_pack in ${ENABLED_PACKS}; do
      if [[ "${pack_name}" == "${enabled_pack}" ]]; then
        enabled=true
        break
      fi
    done
    if [[ "${enabled}" == "false" ]]; then
      echo "SKIP: ${pack_name} (not in ENABLED_PACKS)"
      continue
    fi
  fi

  echo ""
  echo "--- Deploying ${pack_name} ---"
  if bash "${SCRIPT_DIR}/deploy-pack.sh" "${pack_name}" "${ENV_NAME}"; then
    DEPLOYED=$((DEPLOYED + 1))
  else
    echo "ERROR: Failed to deploy ${pack_name}"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "==> Deploy-all complete: ${DEPLOYED} deployed, ${FAILED} failed"

if [[ ${FAILED} -gt 0 ]]; then
  exit 1
fi
