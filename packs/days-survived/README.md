# Days Survived

A Minecraft Bedrock behavior pack that tracks how many in-game days each player has survived and grants configurable one-time milestone rewards with player feedback.

---

## Features

- Tracks elapsed in-game days per player using scoreboard objectives
- Awards one-time milestone rewards at days 1, 5, 10, 25, 50, and 100
- Prevents duplicate rewards using player tags
- Displays actionbar feedback when each milestone is reached
- No experimental flags — uses only vanilla mcfunction commands

---

## Milestones

| Day | Reward | Actionbar Message |
|-----|--------|-------------------|
| 1   | Iron Sword ×1       | §aSurvived 1 day!   |
| 5   | Bread ×16           | §aSurvived 5 days!  |
| 10  | Iron Ingot ×8       | §aSurvived 10 days! |
| 25  | Diamond ×3          | §bSurvived 25 days! |
| 50  | Diamond Sword ×1    | §bSurvived 50 days! |
| 100 | Netherite Ingot ×1  | §6Survived 100 days! |

---

## Installation

### 1. Copy the pack to your server

Copy `packs/days-survived/` into the Bedrock server's `behavior_packs/` directory:

```bash
cp -r packs/days-survived/ /path/to/server/behavior_packs/days-survived/
```

Or use the provided deploy script:

```bash
bash scripts/deploy-pack.sh days-survived test
```

### 2. Register the pack with your world

Edit (or create) `worlds/<YourWorldName>/world_behavior_packs.json` and add:

```json
[
  {
    "pack_id": "8e842647-fe1f-4afd-9345-dd1dbe709c37",
    "version": [1, 0, 0]
  }
]
```

A ready-to-copy example is provided in `world_behavior_packs.json.example`.

### 3. Restart the server

```bash
docker restart <CONTAINER_NAME>
# or
systemctl restart bedrock-server
```

### 4. Initialize scoreboards in-game

On first use, run the init function once in the world console or as a server operator:

```
/function days-survived/init
```

This creates the `tick_counter` and `days_survived` scoreboard objectives. You only need to run this once per world.

---

## Testing

### Verify scoreboards are active

```
/scoreboard objectives list
```

Both `tick_counter` and `days_survived` should appear in the list.

### Check a player's progress

```
/scoreboard players get <playername> days_survived
```

### Fast-forward to test a milestone

To test a specific reward without waiting, temporarily set a player's `days_survived` score:

```
/scoreboard players set <playername> days_survived 5
```

The reward will fire within the next game tick. Remove the reward guard tag first if you want to re-trigger a reward you have already received:

```
/tag <playername> remove reward_day_5
/scoreboard players set <playername> days_survived 5
```

### Validate the pack structure

```bash
bash scripts/validate-pack.sh packs/days-survived
```

---

## How It Works

### Tick counting

`functions/tick.json` registers `days-survived/tick` to run every game tick (20 times per second). The tick function:

1. Increments `tick_counter` for every online player each tick.
2. When `tick_counter` reaches 24,000 (one in-game day at default game speed), increments `days_survived` by 1 and resets `tick_counter` to 0.
3. Checks each milestone selector; if a player's `days_survived` meets or exceeds the milestone threshold and they do not yet have the reward tag, the corresponding reward function is called.

### One-time reward guard

Each reward function immediately adds a player tag (e.g., `reward_day_5`) before granting items. The milestone check in `tick.mcfunction` uses `tag=!reward_day_<N>` to skip players who already have the tag, ensuring each reward is granted exactly once per player.

---

## Extending Reward Tiers

To add a new milestone (for example, day 200):

1. **Create the reward function** at `functions/days-survived/reward_day_200.mcfunction`:

   ```mcfunction
   # reward_day_200.mcfunction — Award milestone reward for surviving 200 days.

   tag @s add reward_day_200
   give @s elytra 1
   title @s actionbar §6Survived 200 days!
   ```

2. **Register the milestone** in `functions/days-survived/tick.mcfunction`:

   ```mcfunction
   # Milestone: day 200
   execute as @a[scores={days_survived=200..},tag=!reward_day_200] run function days-survived/reward_day_200
   ```

3. **Validate and deploy**:

   ```bash
   bash scripts/validate-pack.sh packs/days-survived
   bash scripts/deploy-pack.sh days-survived test
   ```

4. Verify the reward triggers correctly in-game, then promote to production:

   ```bash
   bash scripts/deploy-pack.sh days-survived prod
   ```

> **Note:** Existing players who have already passed day 200 will receive the reward on the next tick after the updated pack loads, unless you manually add the `reward_day_200` tag to them first.
