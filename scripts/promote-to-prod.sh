#!/usr/bin/env bash
# promote-to-prod.sh — Safely promote a pack from test to production.
#
# Usage: bash scripts/promote-to-prod.sh <pack-name>
# Example: bash scripts/promote-to-prod.sh days-survived
#
# This script enforces the test-first promotion workflow:
#  1. Validate the pack files
#  2. Check the deployment log for a prior successful test deployment
#  3. Require explicit "yes" confirmation before touching production
#  4. Deploy to the production environment

set -euo pipefail

PACK_NAME="${1:-}"

if [[ -z "${PACK_NAME}" ]]; then
  echo "ERROR: pack name argument is required."
  echo "Usage: bash scripts/promote-to-prod.sh <pack-name>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${REPO_ROOT}/logs/deployments.log"
PACK_DIR="${REPO_ROOT}/packs/${PACK_NAME}"

if [[ ! -d "${PACK_DIR}" ]]; then
  echo "ERROR: Pack directory not found: ${PACK_DIR}"
  exit 1
fi

# --- Step 1: Validate the pack ---
echo "==> Step 1: Validating ${PACK_NAME}..."
bash "${SCRIPT_DIR}/validate-pack.sh" "${PACK_DIR}"

echo ""

# --- Step 2: Check deployment log for a prior test deployment ---
echo "==> Step 2: Checking for a successful test deployment in the log..."

LAST_TEST_DEPLOY=""
if [[ -f "${LOG_FILE}" ]]; then
  LAST_TEST_DEPLOY=$(grep -F "pack=${PACK_NAME} env=test" "${LOG_FILE}" | grep "status=SUCCESS" | tail -1 || true)
fi

if [[ -n "${LAST_TEST_DEPLOY}" ]]; then
  echo " OK: Found test deployment: ${LAST_TEST_DEPLOY}"
else
  echo "WARN: No successful test deployment found for '${PACK_NAME}' in ${LOG_FILE}"
  echo "      Recommended: deploy and verify on test first:"
  echo "        bash scripts/deploy-pack.sh ${PACK_NAME} test"
  echo ""
  read -rp "Continue to production without a recorded test deployment? [y/N]: " SKIP_CHECK
  if [[ "${SKIP_CHECK}" != "y" && "${SKIP_CHECK}" != "Y" ]]; then
    echo "Aborted. Deploy to test first, verify behavior, then re-run this script."
    exit 1
  fi
fi

echo ""

# --- Step 3: Require explicit confirmation before deploying to production ---
echo "==> Step 3: Production deployment confirmation"
echo ""
echo "  Pack:        ${PACK_NAME}"
echo "  Target:      prod"
echo ""
echo "This will deploy '${PACK_NAME}' to the PRODUCTION server."
read -rp "Type 'yes' to confirm: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

echo ""

# --- Step 4: Deploy to production (bypass the interactive guard in deploy-pack.sh) ---
echo "==> Step 4: Deploying ${PACK_NAME} to production..."
SKIP_PROD_CONFIRM=1 bash "${SCRIPT_DIR}/deploy-pack.sh" "${PACK_NAME}" prod

echo ""
echo "DONE: ${PACK_NAME} promoted to production."
