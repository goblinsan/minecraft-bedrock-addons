# tick.mcfunction — Runs every game tick for all online players.
# Registered in functions/tick.json.
#
# Prerequisite: run /function days-survived/init once when first attaching
# this pack to a world to create the required scoreboard objectives.

# Increment tick counter for all online players
scoreboard players add @a tick_counter 1

# When tick_counter reaches 24000 (one in-game day), increment days_survived and reset
execute as @a[scores={tick_counter=24000..}] run scoreboard players add @s days_survived 1
execute as @a[scores={tick_counter=24000..}] run scoreboard players set @s tick_counter 0

# Milestone: day 1
execute as @a[scores={days_survived=1..},tag=!reward_day_1] run function days-survived/reward_day_1

# Milestone: day 7
execute as @a[scores={days_survived=7..},tag=!reward_day_7] run function days-survived/reward_day_7

# Milestone: day 30
execute as @a[scores={days_survived=30..},tag=!reward_day_30] run function days-survived/reward_day_30
