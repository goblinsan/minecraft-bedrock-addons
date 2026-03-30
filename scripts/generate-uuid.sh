#!/usr/bin/env bash
# generate-uuid.sh — Generate two unique UUID v4 values for use in a pack manifest.
#
# Usage: bash scripts/generate-uuid.sh

set -euo pipefail

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

echo "Generated UUIDs for manifest.json:"
echo ""
echo "  header.uuid:        ${UUID1}"
echo "  modules[0].uuid:    ${UUID2}"
echo ""
echo "Replace the placeholder values in your manifest.json with these values."
