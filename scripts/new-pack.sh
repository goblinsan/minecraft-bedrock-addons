#!/usr/bin/env bash
# new-pack.sh — Scaffold a new behavior pack from the shared template.
#
# Usage: bash scripts/new-pack.sh <pack-name>
#
# This script:
#   1. Creates packs/<pack-name>/ from the template scaffold
#   2. Generates two UUID v4 values and injects them into manifest.json
#   3. Renames the placeholder namespace to match the pack name

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/shared/templates/new-pack-template"

if [[ $# -lt 1 ]]; then
  echo "Usage: bash scripts/new-pack.sh <pack-name>"
  echo ""
  echo "Example: bash scripts/new-pack.sh daily-quests"
  exit 1
fi

PACK_NAME="$1"

# Validate pack name: lowercase letters, digits, and hyphens only
if [[ ! "${PACK_NAME}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERROR: pack name must be kebab-case (lowercase letters, digits, hyphens)."
  echo "       Example: daily-quests, loot-events, fun-pack"
  exit 1
fi

PACK_DIR="${REPO_ROOT}/packs/${PACK_NAME}"

if [[ -e "${PACK_DIR}" ]]; then
  echo "ERROR: ${PACK_DIR} already exists. Choose a different pack name."
  exit 1
fi

echo "Scaffolding new pack: ${PACK_NAME}"

# Copy template scaffold
cp -r "${TEMPLATE_DIR}" "${PACK_DIR}"

# Rename the placeholder namespace directory to match the pack name
if [[ -d "${PACK_DIR}/functions/template" ]]; then
  mv "${PACK_DIR}/functions/template" "${PACK_DIR}/functions/${PACK_NAME}"
fi

# Update tick.json to reference the correct namespace
TICK_JSON="${PACK_DIR}/functions/tick.json"
if [[ -f "${TICK_JSON}" ]]; then
  sed -i.bak "s|template/tick|${PACK_NAME}/tick|g" "${TICK_JSON}"
  rm -f "${TICK_JSON}.bak"
fi

# Update function path references inside mcfunction files
for f in "${PACK_DIR}/functions/${PACK_NAME}/"*.mcfunction; do
  [[ -f "$f" ]] || continue
  sed -i.bak "s|template/|${PACK_NAME}/|g" "$f"
  rm -f "$f.bak"
done

# Generate two UUID v4 values
if command -v uuidgen &>/dev/null; then
  UUID1=$(uuidgen | tr '[:upper:]' '[:lower:]')
  UUID2=$(uuidgen | tr '[:upper:]' '[:lower:]')
elif command -v python3 &>/dev/null; then
  UUID1=$(python3 -c "import uuid; print(uuid.uuid4())")
  UUID2=$(python3 -c "import uuid; print(uuid.uuid4())")
else
  echo "WARNING: neither uuidgen nor python3 found."
  echo "         Replace the placeholder UUIDs in ${PACK_DIR}/manifest.json manually."
  UUID1="REPLACE-WITH-UNIQUE-UUID-v4-HEADER"
  UUID2="REPLACE-WITH-UNIQUE-UUID-v4-MODULE"
fi

# Inject UUIDs into manifest.json
MANIFEST="${PACK_DIR}/manifest.json"
sed -i.bak \
  -e "s|REPLACE-WITH-UNIQUE-UUID-v4-HEADER|${UUID1}|g" \
  -e "s|REPLACE-WITH-UNIQUE-UUID-v4-MODULE|${UUID2}|g" \
  "${MANIFEST}"
rm -f "${MANIFEST}.bak"

echo ""
echo "Pack scaffolded at: ${PACK_DIR}"
echo ""
echo "  manifest.json:             update 'name' and 'description'"
echo "  functions/${PACK_NAME}/init.mcfunction:  add scoreboard objectives"
echo "  functions/${PACK_NAME}/tick.mcfunction:  add per-tick logic"
echo ""
echo "Next steps:"
echo "  1. Edit ${PACK_DIR}/manifest.json"
echo "  2. Write your functions in ${PACK_DIR}/functions/${PACK_NAME}/"
echo "  3. bash scripts/validate-pack.sh ${PACK_DIR}"
echo "  4. bash scripts/deploy-pack.sh ${PACK_NAME} test"
