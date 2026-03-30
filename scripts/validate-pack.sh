#!/usr/bin/env bash
# validate-pack.sh — Validate the structure, manifest, and JSON files in a pack.
#
# Usage: bash scripts/validate-pack.sh <pack-directory>
# Example: bash scripts/validate-pack.sh packs/days-survived

set -euo pipefail

PACK_DIR="${1:-}"

if [[ -z "${PACK_DIR}" ]]; then
  echo "ERROR: pack directory argument is required."
  echo "Usage: bash scripts/validate-pack.sh <pack-directory>"
  exit 1
fi

if [[ ! -d "${PACK_DIR}" ]]; then
  echo "ERROR: Directory not found: ${PACK_DIR}"
  exit 1
fi

echo "==> Validating pack: ${PACK_DIR}"

ERRORS=0

# --- Check manifest.json exists ---
MANIFEST="${PACK_DIR}/manifest.json"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "FAIL: manifest.json not found in ${PACK_DIR}"
  ERRORS=$((ERRORS + 1))
else
  echo " OK: manifest.json found"

  # --- Check manifest.json is valid JSON ---
  if ! jq empty "${MANIFEST}" 2>/dev/null; then
    echo "FAIL: manifest.json is not valid JSON"
    ERRORS=$((ERRORS + 1))
  else
    echo " OK: manifest.json is valid JSON"

    # --- Check required UUID fields ---
    HEADER_UUID=$(jq -r '.header.uuid // empty' "${MANIFEST}")
    MODULE_UUID=$(jq -r '.modules[0].uuid // empty' "${MANIFEST}")

    if [[ -z "${HEADER_UUID}" ]]; then
      echo "FAIL: manifest.json missing header.uuid"
      ERRORS=$((ERRORS + 1))
    else
      echo " OK: header.uuid = ${HEADER_UUID}"
    fi

    if [[ -z "${MODULE_UUID}" ]]; then
      echo "FAIL: manifest.json missing modules[0].uuid"
      ERRORS=$((ERRORS + 1))
    else
      echo " OK: modules[0].uuid = ${MODULE_UUID}"
    fi

    if [[ "${HEADER_UUID}" == "${MODULE_UUID}" ]] && [[ -n "${HEADER_UUID}" ]]; then
      echo "FAIL: header.uuid and modules[0].uuid must be different"
      ERRORS=$((ERRORS + 1))
    fi

    # --- Warn about placeholder UUIDs ---
    if [[ "${HEADER_UUID}" == REPLACE-* ]] || [[ "${MODULE_UUID}" == REPLACE-* ]]; then
      echo "WARN: manifest.json still contains placeholder UUIDs — replace before deploying"
    fi
  fi
fi

# --- Validate all JSON files under the pack ---
while IFS= read -r -d '' json_file; do
  if ! jq empty "${json_file}" 2>/dev/null; then
    echo "FAIL: invalid JSON in ${json_file}"
    ERRORS=$((ERRORS + 1))
  else
    echo " OK: ${json_file}"
  fi
done < <(find "${PACK_DIR}" -name "*.json" -print0)

# --- Check that .mcfunction files are non-empty ---
while IFS= read -r -d '' func_file; do
  if [[ ! -s "${func_file}" ]]; then
    echo "WARN: empty function file: ${func_file}"
  else
    echo " OK: ${func_file}"
  fi
done < <(find "${PACK_DIR}" -name "*.mcfunction" -print0)

echo ""
if [[ ${ERRORS} -gt 0 ]]; then
  echo "FAIL: ${ERRORS} error(s) found in ${PACK_DIR}"
  exit 1
else
  echo "PASS: ${PACK_DIR} is valid"
fi
