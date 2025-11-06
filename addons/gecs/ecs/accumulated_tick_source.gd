## AccumulatedTickSource
##
## Time-based tick source that fires at intervals but returns the actual accumulated time.
##
## Similar to IntervalTickSource, but returns the actual accumulated delta instead of
## the fixed interval. Useful when you need to account for time drift or variable frame rates.
##
## [b]Example:[/b]
## [codeblock]
## # In world setup
## var physics_tick = AccumulatedTickSource.new()
## physics_tick.interval = 0.02  # ~50 FPS
## ECS.world.register_tick_source(physics_tick, "physics-tick")
##
## # In system
## class_name PhysicsSystem extends System
##
## func tick() -> TickSource:
##     return ECS.world.get_tick_source("physics-tick")
##
## func process(entities: Array[Entity], components: Array, delta: float) -> void:
##     # delta will be the actual accumulated time (e.g., 0.021 if slightly behind)
##     apply_physics(entities, delta)
## [/codeblock]
class_name AccumulatedTickSource
extends TickSource

## The interval in seconds between ticks
@export var interval: float = 1.0

## Accumulated time since last tick
var accumulated_time: float = 0.0

## Total number of ticks that have occurred
var tick_count: int = 0


## Update the tick source with frame delta
## Returns the accumulated time when it's time to tick, 0.0 otherwise
func update(delta: float) -> float:
	accumulated_time += delta

	if accumulated_time >= interval:
		tick_count += 1
		last_delta = accumulated_time  # Actual accumulated time
		accumulated_time = 0.0
	else:
		last_delta = 0.0  # No tick this frame

	return last_delta


## Reset tick source state
func reset() -> void:
	super.reset()
	accumulated_time = 0.0
	tick_count = 0
