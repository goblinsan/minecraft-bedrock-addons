# init.mcfunction — Initialize scoreboards for the days-survived pack.
# Run once when attaching this pack to a new world:
#   /function days-survived/init

scoreboard objectives add tick_counter dummy "Tick Counter"
scoreboard objectives add days_survived dummy "Days Survived"
