#!/usr/bin/env bash
# generate-uuid.sh — Generate two unique UUID v4 values for use in a pack manifest.
#
# Usage:
#   bash scripts/generate-uuid.sh                        # print UUIDs to stdout
#   bash scripts/generate-uuid.sh --inject <manifest>    # write UUIDs into manifest.json

set -euo pipefail

INJECT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --inject)
      shift
      if [[ $# -lt 1 ]]; then
        echo "ERROR: --inject requires a path to a manifest.json file."
        exit 1
      fi
      INJECT_FILE="$1"
      shift
      ;;
    *)
      echo "Usage: bash scripts/generate-uuid.sh [--inject <manifest.json>]"
      exit 1
      ;;
  esac
done

if [[ -n "${INJECT_FILE}" && ! -f "${INJECT_FILE}" ]]; then
  echo "ERROR: manifest file not found: ${INJECT_FILE}"
  exit 1
fi

if command -v uuidgen &>/dev/null; then
  UUID1=$(uuidgen | tr '[:upper:]' '[:lower:]')
  UUID2=$(uuidgen | tr '[:upper:]' '[:lower:]')
elif command -v python3 &>/dev/null; then
  UUID1=$(python3 -c "import uuid; print(uuid.uuid4())")
  UUID2=$(python3 -c "import uuid; print(uuid.uuid4())")
else
  echo "ERROR: neither uuidgen nor python3 found. Install one to generate UUIDs."
  exit 1
fi

if [[ -n "${INJECT_FILE}" ]]; then
  sed -i.bak \
    -e "s|REPLACE-WITH-UNIQUE-UUID-v4-HEADER|${UUID1}|g" \
    -e "s|REPLACE-WITH-UNIQUE-UUID-v4-MODULE|${UUID2}|g" \
    "${INJECT_FILE}"
  rm -f "${INJECT_FILE}.bak"
  echo "Injected UUIDs into ${INJECT_FILE}:"
  echo ""
  echo "  header.uuid:        ${UUID1}"
  echo "  modules[0].uuid:    ${UUID2}"
else
  echo "Generated UUIDs for manifest.json:"
  echo ""
  echo "  header.uuid:        ${UUID1}"
  echo "  modules[0].uuid:    ${UUID2}"
  echo ""
  echo "Replace the placeholder values in your manifest.json with these values."
  echo "Or run: bash scripts/generate-uuid.sh --inject <path/to/manifest.json>"
fi
