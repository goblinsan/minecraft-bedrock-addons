# Add-on Development Guide

This guide walks through the complete workflow for creating, validating, and iterating on a Bedrock behavior pack in this repository.

---

## Overview

The development loop:

```
1. Create pack structure
2. Write / edit mcfunction files
3. validate-pack.sh  →  fix any errors
4. deploy-pack.sh (test environment)
5. Reload / restart test server
6. Verify in-game behavior
7. Repeat steps 2–6 until correct
8. deploy-pack.sh (prod environment)
```

---

## Step 1 — Create a New Pack

### Copy the Template Manifest

```bash
PACK_NAME="my-pack"
mkdir -p packs/${PACK_NAME}/functions/${PACK_NAME}
cp shared/templates/behavior-pack-manifest.json packs/${PACK_NAME}/manifest.json
```

### Generate UUIDs

Each pack needs **two** unique UUID v4 values (one for the header, one for the module). Generate them:

```bash
# On macOS / Linux with uuidgen
uuidgen   # copy for header.uuid
uuidgen   # copy for modules[0].uuid
```

Or use `scripts/generate-uuid.sh`:

```bash
bash scripts/generate-uuid.sh
```

### Fill In manifest.json

Edit `packs/${PACK_NAME}/manifest.json`:

```json
{
  "format_version": 2,
  "header": {
    "name": "My Pack",
    "description": "What this pack does",
    "uuid": "<uuid-1>",
    "version": [1, 0, 0],
    "min_engine_version": [1, 20, 0]
  },
  "modules": [
    {
      "type": "data",
      "uuid": "<uuid-2>",
      "version": [1, 0, 0]
    }
  ]
}
```

---

## Step 2 — Write Functions

### Directory Layout

```
packs/my-pack/functions/
├── tick.json                   # Optional: run functions every tick
└── my-pack/
    ├── init.mcfunction         # Run once on world load (via /function command or event)
    ├── tick.mcfunction         # Called every tick if registered in tick.json
    └── reward_day_1.mcfunction # Example milestone reward
```

### tick.json

To run a function every tick, create `packs/my-pack/functions/tick.json`:

```json
{
  "values": [
    "my-pack/tick"
  ]
}
```

### Example: per-tick day tracking

`packs/my-pack/functions/my-pack/tick.mcfunction`:

```mcfunction
# Increment tick counter for all online players
scoreboard players add @a tick_counter 1

# When tick_counter reaches 24000 (one in-game day), increment days_survived
execute as @a[scores={tick_counter=24000..}] run scoreboard players add @s days_survived 1
execute as @a[scores={tick_counter=24000..}] run scoreboard players set @s tick_counter 0

# Check milestones
execute as @a[scores={days_survived=1..},tag=!reward_day_1] run function my-pack/reward_day_1
```

`packs/my-pack/functions/my-pack/reward_day_1.mcfunction`:

```mcfunction
tag @s add reward_day_1
give @s iron_sword 1
title @s actionbar §aSurvived 1 day!
```

### Init Function

For scoreboards that must be created before use, provide an init function and document that it should be run once when attaching the pack to a new world:

`packs/my-pack/functions/my-pack/init.mcfunction`:

```mcfunction
scoreboard objectives add tick_counter dummy "Tick Counter"
scoreboard objectives add days_survived dummy "Days Survived"
```

---

## Step 3 — Validate the Pack

```bash
bash scripts/validate-pack.sh packs/my-pack
```

The script checks:
- Required files exist (`manifest.json`)
- `manifest.json` is valid JSON
- `header.uuid` and `modules[0].uuid` are both present and non-empty
- All `.mcfunction` and `.json` files under `functions/` parse without errors

Fix any reported issues before proceeding.

---

## Step 4 — Deploy to the Test Server

```bash
bash scripts/deploy-pack.sh my-pack test
```

This reads `environments/test.env` and:
1. Copies `packs/my-pack/` to the Bedrock server's `behavior_packs/` directory
2. Updates `worlds/<world>/world_behavior_packs.json` with the pack UUID and version
3. Optionally restarts the container

---

## Step 5 — Verify in the Test World

1. Join the test server world
2. Run `/function my-pack/init` to initialize scoreboards (first time only)
3. Observe behavior: check `days_survived` scoreboard, verify rewards trigger at correct milestones
4. Check server logs for command errors

---

## Step 6 — Iterate

Edit your `.mcfunction` files and repeat steps 3–5 until the pack behaves correctly.

**Tip:** You can reload behavior packs without a full server restart by running `/reload` in-game on some Bedrock versions, but a full restart is more reliable.

---

## Step 7 — Promote to Production

Once verified on the test server:

```bash
bash scripts/deploy-pack.sh my-pack prod
```

See [deployment-guide.md](deployment-guide.md) for full production deployment procedures and rollback instructions.

---

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Pack directory | kebab-case | `days-survived` |
| Function namespace | matches pack directory | `days-survived/` |
| Function files | snake_case | `reward_day_1.mcfunction` |
| Scoreboard objectives | snake_case | `days_survived` |
| Tag names | snake_case | `reward_day_1` |
| Manifest name | Title Case | `"Days Survived"` |

---

## Tips for GitHub Copilot

- Keep function files small and focused on a single behavior
- Add a comment at the top of each `.mcfunction` file describing its purpose
- Use consistent scoreboard and tag names that match the pack's domain
- The manifest template in `shared/templates/` gives Copilot context about expected structure
