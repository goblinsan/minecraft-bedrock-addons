# Add-on Roadmap

This document captures recommended patterns for planned add-on packs so future contributions fit naturally into the repository and can reuse the existing deployment and validation workflows.

Each section describes the pack's purpose, suggested scoreboard/tag conventions, key mcfunction files, and how to scaffold it.

---

## Quick Start for Any New Pack

```bash
# Scaffold a new pack from the shared template (auto-generates UUIDs)
bash scripts/new-pack.sh <pack-name>

# Validate structure and JSON
bash scripts/validate-pack.sh packs/<pack-name>

# Deploy to the test server
bash scripts/deploy-pack.sh <pack-name> test
```

See [addon-development-guide.md](addon-development-guide.md) for the full development loop.

---

## Planned Packs

### 1. Player Classes (`player-classes`)

**Purpose:** Let players choose a class (Warrior, Archer, Mage, etc.) that grants passive bonuses and unlocks class-specific abilities.

**Scaffold:**

```bash
bash scripts/new-pack.sh player-classes
```

**Scoreboards:**

| Objective | Type | Description |
|---|---|---|
| `cls_id` | `dummy` | Numeric class identifier (1 = Warrior, 2 = Archer, 3 = Mage) |
| `cls_xp` | `dummy` | Experience points earned within the current class |
| `cls_level` | `dummy` | Level within the current class |

**Tags:**

| Tag | Meaning |
|---|---|
| `cls_warrior` | Player has chosen the Warrior class |
| `cls_archer` | Player has chosen the Archer class |
| `cls_mage` | Player has chosen the Mage class |
| `cls_selected` | Player has completed class selection |

**Suggested function layout:**

```
packs/player-classes/functions/
├── tick.json
└── player-classes/
    ├── init.mcfunction          # Create scoreboards; run once on world load
    ├── tick.mcfunction          # Apply passive class bonuses each tick
    ├── select_warrior.mcfunction
    ├── select_archer.mcfunction
    ├── select_mage.mcfunction
    └── reset_class.mcfunction   # Remove all class tags and reset scores
```

**Notes:**
- Gate class selection behind a one-time check: `tag=!cls_selected`
- Apply effects (e.g., `effect @s[tag=cls_warrior] strength`) on a cooldown tick rather than every tick to avoid spam

---

### 2. Daily Quests (`daily-quests`)

**Purpose:** Give players a rotating set of tasks to complete each in-game day, rewarding currency, items, or XP on completion.

**Scaffold:**

```bash
bash scripts/new-pack.sh daily-quests
```

**Scoreboards:**

| Objective | Type | Description |
|---|---|---|
| `dq_day` | `dummy` | In-game day number; used to rotate the active quest set |
| `dq_progress` | `dummy` | Per-player progress toward the current quest goal |
| `dq_streak` | `dummy` | Consecutive days with at least one completed quest |

**Tags:**

| Tag | Meaning |
|---|---|
| `dq_complete_<n>` | Player completed quest slot *n* today (e.g., `dq_complete_1`) |
| `dq_rewarded` | Player has already received today's completion reward |

**Suggested function layout:**

```
packs/daily-quests/functions/
├── tick.json
└── daily-quests/
    ├── init.mcfunction          # Create scoreboards
    ├── tick.mcfunction          # Increment progress; check completion thresholds
    ├── check_day_rollover.mcfunction  # Detect new day and reset quest state
    ├── complete_quest_1.mcfunction
    ├── complete_quest_2.mcfunction
    └── reward.mcfunction        # Grant daily reward items or currency
```

**Notes:**
- Use `dq_day` compared against a stored value to detect day rollover without a real-time clock
- Keep quest goals achievable in a single play session for kid-friendly accessibility

---

### 3. Loot Events (`loot-events`)

**Purpose:** Trigger periodic world events that spawn bonus loot, activate treasure chests, or temporarily buff drop rates.

**Scaffold:**

```bash
bash scripts/new-pack.sh loot-events
```

**Scoreboards:**

| Objective | Type | Description |
|---|---|---|
| `le_timer` | `dummy` | Tick countdown until the next loot event fires |
| `le_event_id` | `dummy` | Which event type is currently active (0 = none) |
| `le_claims` | `dummy` | Number of times the active event has been claimed globally |

**Tags:**

| Tag | Meaning |
|---|---|
| `le_claimed_<id>` | Player has claimed event *id* (e.g., `le_claimed_3`) |
| `le_active` | A loot event is currently running |

**Suggested function layout:**

```
packs/loot-events/functions/
├── tick.json
└── loot-events/
    ├── init.mcfunction          # Create scoreboards; seed le_timer
    ├── tick.mcfunction          # Decrement timer; trigger events at zero
    ├── start_event.mcfunction   # Announce event and set le_event_id
    ├── end_event.mcfunction     # Clear event state and reset timer
    ├── event_gold_rush.mcfunction    # Example: double gold drops for 5 minutes
    └── event_treasure_drop.mcfunction  # Example: drop bonus treasure for nearby players
```

**Notes:**
- Use `le_timer` as a simple countdown: set to a large tick value (e.g., 72000 = 1 hour) in `init`, decrement in `tick`, fire event at zero, reset after
- Guard per-player claims with tags so players cannot claim the same event twice

---

### 4. Fun Pack (`fun-pack`)

**Purpose:** Kid-friendly, low-stakes mechanics — silly particle effects, random cosmetic rewards, joke items, and celebration commands for milestones (first kill, first build, first night survived).

**Scaffold:**

```bash
bash scripts/new-pack.sh fun-pack
```

**Scoreboards:**

| Objective | Type | Description |
|---|---|---|
| `fun_actions` | `dummy` | Cumulative fun-related actions (builds, kills, etc.) |
| `fun_level` | `dummy` | Current "fun level" tier, unlocks new effects |

**Tags:**

| Tag | Meaning |
|---|---|
| `fun_first_night` | Player survived their first night |
| `fun_first_build` | Player placed their first block |
| `fun_confetti_<n>` | Player unlocked confetti effect tier *n* |

**Suggested function layout:**

```
packs/fun-pack/functions/
├── tick.json
└── fun-pack/
    ├── init.mcfunction
    ├── tick.mcfunction          # Check fun milestones
    ├── celebrate.mcfunction     # Particle + sound + title burst
    ├── first_night.mcfunction   # Reward for first night survived
    └── level_up.mcfunction      # Fun level-up fanfare
```

**Notes:**
- Use `particle` and `playsound` commands generously — these are the main tools for visual/audio feedback without experimental flags
- Keep reward items cosmetic or consumable (fireworks, cake, flowers) to stay kid-friendly
- Use `tag=!fun_first_night` guards so each milestone triggers exactly once per player

---

### 5. Economy Pack (`economy`)

**Purpose:** A lightweight token-based economy using scoreboards as currency. Players earn tokens through activity and can spend them via in-game "shop" functions.

**Scaffold:**

```bash
bash scripts/new-pack.sh economy
```

**Scoreboards:**

| Objective | Type | Description |
|---|---|---|
| `eco_tokens` | `dummy` | Current token balance per player |
| `eco_earned` | `dummy` | Lifetime tokens earned (for leaderboards) |
| `eco_spent` | `dummy` | Lifetime tokens spent |

**Tags:**

| Tag | Meaning |
|---|---|
| `eco_shop_access` | Player has been granted shop access |
| `eco_purchase_<item>` | Player has purchased a specific item (prevents duplicate purchases of one-time items) |

**Suggested function layout:**

```
packs/economy/functions/
├── tick.json
└── economy/
    ├── init.mcfunction              # Create scoreboard objectives
    ├── tick.mcfunction              # Award passive token income (e.g., 1 token/minute)
    ├── earn.mcfunction              # Called by other packs to award tokens
    ├── spend.mcfunction             # Deduct tokens; reject if balance insufficient
    ├── shop_list.mcfunction         # Show available items via title/actionbar
    ├── buy_iron_sword.mcfunction    # Example purchase: costs 10 tokens
    └── buy_golden_apple.mcfunction  # Example purchase: costs 25 tokens
```

**Notes:**
- Call `economy/earn` from other packs (e.g., `daily-quests`, `loot-events`) to award tokens as cross-pack rewards
- Guard token deductions: check `scores={eco_tokens=10..}` before running `spend` to avoid negative balances
- Keep the economy self-contained; other packs depend on it by calling its public functions, not by manipulating the `eco_tokens` scoreboard directly

---

## Cross-Pack Conventions

When multiple packs are deployed together, follow these conventions to avoid conflicts.

### Scoreboard Namespacing

Prefix all scoreboard objective names with a short pack identifier:

| Pack | Prefix | Example |
|---|---|---|
| `player-classes` | `cls_` | `cls_id`, `cls_xp` |
| `daily-quests` | `dq_` | `dq_day`, `dq_progress` |
| `loot-events` | `le_` | `le_timer`, `le_event_id` |
| `fun-pack` | `fun_` | `fun_actions`, `fun_level` |
| `economy` | `eco_` | `eco_tokens`, `eco_earned` |

> **Note:** The existing `days-survived` pack uses unprefixed names (`tick_counter`, `days_survived`) for historical reasons. All new packs should use prefixes.

### Tag Namespacing

Prefix all tag names with the pack's short identifier:

```mcfunction
# Good — unambiguous
tag @s add cls_warrior
tag @s add dq_complete_1

# Avoid — collides with other packs
tag @s add warrior
tag @s add complete
```

### Function Calling Between Packs

Call a public function from another pack using its full path:

```mcfunction
# Award economy tokens from a daily-quests reward function
function economy/earn
```

Document cross-pack dependencies in each pack's `README.md` so deployers know which packs must be present together.
