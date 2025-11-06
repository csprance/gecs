## IntervalTickSource
##
## Time-based tick source that fires at fixed intervals.
##
## Returns a fixed interval delta when the accumulated time exceeds the interval.
## Useful for systems that need to run at specific time intervals (e.g., every 1 second).
##
## [b]Example:[/b]
## [codeblock]
## # In world setup
## var spawner_tick = IntervalTickSource.new()
## spawner_tick.interval = 1.0  # Tick every second
## ECS.world.register_tick_source(spawner_tick, "spawner-tick")
##
## # In system
## class_name SpawnerSystem extends System
##
## func tick() -> TickSource:
##     return ECS.world.get_tick_source("spawner-tick")
##
## func process(entities: Array[Entity], components: Array, delta: float) -> void:
##     # This runs every 1 second with delta = 1.0
##     spawn_enemy()
## [/codeblock]
class_name IntervalTickSource
extends TickSource

## The interval in seconds between ticks
@export var interval: float = 1.0

## Accumulated time since last tick
var accumulated_time: float = 0.0

## Total number of ticks that have occurred
var tick_count: int = 0


## Update the tick source with frame delta
## Returns the fixed interval when it's time to tick, 0.0 otherwise
func update(delta: float) -> float:
	accumulated_time += delta

	if accumulated_time >= interval:
		tick_count += 1
		accumulated_time -= interval
		last_delta = interval  # Fixed interval
	else:
		last_delta = 0.0  # No tick this frame

	return last_delta


## Reset tick source state
func reset() -> void:
	super.reset()
	accumulated_time = 0.0
	tick_count = 0
