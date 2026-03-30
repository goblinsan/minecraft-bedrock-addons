# Architecture

This document describes the key design decisions, Bedrock Edition constraints, and patterns used throughout this repository.

---

## Bedrock Edition Constraints

Understanding these constraints is essential before building any add-on.

### No JavaScript / No Scripting API (Vanilla Function Packs)
The `days-survived` pack and most packs in this repo intentionally use only **mcfunction files** and the **vanilla command system**. This avoids the Bedrock Scripting API (GameTest/Script API), which requires experimental gameplay flags and can break between server updates.

### Pack Types
| Type | Purpose | Location on Server |
|---|---|---|
| Behavior Pack | Functions, loot tables, entity behavior, tick logic | `behavior_packs/` |
| Resource Pack | Textures, sounds, models, UI | `resource_packs/` |

Each pack in this repo lives under `packs/<pack-name>/` and is self-contained.

### World Registration
Packs are not active until they are registered to a world via:
- `worlds/<world-name>/world_behavior_packs.json`
- `worlds/<world-name>/world_resource_packs.json`

These files must contain the pack UUID and version from `manifest.json`. Deployment scripts in this repo handle this automatically.

### Tick Execution
Bedrock supports a `tick.json` file inside a behavior pack to run one or more functions every game tick (20 times per second). This is the mechanism used for real-time tracking (e.g., day counters).

```json
{
  "values": [
    "namespace/tick_function"
  ]
}
```

Use `tick.json` conservatively — heavy per-tick logic causes server lag.

---

## Pack Structure

Every behavior pack under `packs/` follows this layout:

```
packs/<pack-name>/
├── manifest.json          # Required. Identifies the pack to Bedrock.
├── pack_icon.png          # Optional but recommended (256×256 PNG).
└── functions/             # mcfunction files organized by namespace.
    ├── tick.json          # Optional. Lists functions to run every tick.
    └── <namespace>/
        ├── main.mcfunction
        ├── rewards.mcfunction
        └── ...
```

### manifest.json Fields

```json
{
  "format_version": 2,
  "header": {
    "name": "Pack Display Name",
    "description": "Short description shown in-game",
    "uuid": "<unique-uuid-v4>",
    "version": [1, 0, 0],
    "min_engine_version": [1, 20, 0]
  },
  "modules": [
    {
      "type": "data",
      "uuid": "<different-unique-uuid-v4>",
      "version": [1, 0, 0]
    }
  ]
}
```

**Important:** The `header.uuid` and `modules[0].uuid` **must be different** and must be unique across all packs. Use `scripts/generate-uuid.sh` or an online UUID v4 generator.

---

## Scoreboard Patterns

Scoreboards are the primary state persistence mechanism for vanilla Bedrock packs.

### Declaring a Scoreboard
Run once on world load or from an init function:

```mcfunction
scoreboard objectives add days_survived dummy "Days Survived"
```

### Incrementing a Counter

```mcfunction
# Increment a tick counter for all players
scoreboard players add @a tick_counter 1
```

### Resetting to Zero

```mcfunction
scoreboard players set @a tick_counter 0
```

### Threshold Check (trigger rewards at milestones)

```mcfunction
# Execute reward function for players who just hit day 1
execute as @a[scores={days_survived=1}] run function days_survived/reward_day_1
```

### One-Time Reward Guard (using tags)

Tags are the simplest guard to prevent duplicate rewards:

```mcfunction
# Grant reward only if player does not already have the tag
execute as @a[scores={days_survived=1..},tag=!reward_day_1] run function days_survived/reward_day_1
```

Inside `reward_day_1.mcfunction`, add the tag after granting the reward:

```mcfunction
tag @s add reward_day_1
give @s diamond 1
title @s actionbar §aSurvived 1 day!
```

### Converting Ticks to Days

Bedrock game time: **1 real second = 20 ticks**, **1 in-game day = 24,000 ticks** (at default speed).

To track in-game days without `tick.json`, you can use a scoreboard that increments on `time` and checks for multiples of 24000. The recommended approach in this repo is a dedicated `tick_counter` scoreboard that resets after reaching 24000.

---

## Environment Separation

| Environment | Purpose |
|---|---|
| `test` | Local or containerized Bedrock server used to verify packs before promotion |
| `prod` | Live server(s) serving actual players |

Configuration lives in `environments/test.env` and `environments/prod.env` (copies of the `.example.env` files). Scripts consume these files. See [deployment-guide.md](deployment-guide.md) for details.

---

## Design Principles

1. **Self-contained packs** — each pack under `packs/` should be deployable independently
2. **No experimental flags** — avoid Bedrock experimental gameplay toggles unless explicitly required
3. **Fail loudly** — scripts exit on errors; deployment never silently skips validation
4. **Minimal dependencies** — bash + jq is sufficient for the entire toolchain
5. **Copilot-friendly naming** — consistent file names and directory structures improve AI code suggestion quality
