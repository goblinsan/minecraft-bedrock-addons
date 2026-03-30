#!/usr/bin/env bash
# build-pack.sh — Package a named pack into a .zip file for deployment or sharing.
#
# Usage: bash scripts/build-pack.sh <pack-name>
# Example: bash scripts/build-pack.sh days-survived
# Output: dist/<pack-name>.zip

set -euo pipefail

PACK_NAME="${1:-}"

if [[ -z "${PACK_NAME}" ]]; then
  echo "ERROR: pack name argument is required."
  echo "Usage: bash scripts/build-pack.sh <pack-name>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACK_DIR="${REPO_ROOT}/packs/${PACK_NAME}"
DIST_DIR="${REPO_ROOT}/dist"

if [[ ! -d "${PACK_DIR}" ]]; then
  echo "ERROR: Pack directory not found: ${PACK_DIR}"
  exit 1
fi

echo "==> Validating ${PACK_NAME} before building..."
bash "${SCRIPT_DIR}/validate-pack.sh" "${PACK_DIR}"

mkdir -p "${DIST_DIR}"

OUTPUT="${DIST_DIR}/${PACK_NAME}.zip"
echo "==> Building ${PACK_NAME} → ${OUTPUT}"

# Remove any previous build artifact
rm -f "${OUTPUT}"

# Create zip from the pack directory (contents, not the directory itself)
(cd "${PACK_DIR}" && zip -r "${OUTPUT}" . -x "*.DS_Store" -x "__MACOSX/*")

echo "DONE: ${OUTPUT}"
