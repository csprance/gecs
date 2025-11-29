## RateFilterTickSource
##
## Frame-based tick source that samples another tick source at a specific rate.
##
## Ticks every Nth time the source ticks, accumulating the delta values.
## Useful for creating hierarchical timing systems and deterministic frame-based execution.
##
## [b]Example:[/b]
## [codeblock]
## # In world setup
## ECS.world.create_interval_tick_source(1.0, "second")
## ECS.world.create_rate_filter(60, "second", "minute")  # Every 60 seconds
##
## # In system
## class_name AutoSaveSystem extends System
##
## func tick() -> TickSource:
##     return ECS.world.get_tick_source("minute")
##
## func process(entities: Array[Entity], components: Array, delta: float) -> void:
##     # This runs every 60 seconds
##     # delta will be the accumulated time from 60 ticks (~60 seconds)
##     auto_save_game()
## [/codeblock]
##
## [b]Note:[/b] The source tick source is NOT updated by this class - World updates
## all tick sources in order, so we just read the source's last_delta from its update.
class_name RateFilterTickSource
extends TickSource

## The number of source ticks to wait before ticking
@export var rate: int = 60

## The source tick source to sample (set by World.create_rate_filter)
@export var source: TickSource

## Internal counter for source ticks
var tick_count: int = 0

## Accumulated delta from source ticks
var accumulated_delta: float = 0.0


## Update the tick source
## Samples the source's last_delta and ticks every Nth source tick
## Returns the accumulated delta when it's time to tick, 0.0 otherwise
func update(delta: float) -> float:
	# NOTE: Source is NOT updated here - World updates all tick sources
	# We just read the source's last_delta from its previous update

	if source.last_delta > 0.0:  # Source ticked this frame
		tick_count += 1
		accumulated_delta += source.last_delta

		if tick_count >= rate:
			tick_count = 0
			last_delta = accumulated_delta  # Return accumulated delta
			accumulated_delta = 0.0
		else:
			last_delta = 0.0  # Not time to tick yet
	else:
		last_delta = 0.0  # Source didn't tick

	return last_delta


## Reset tick source state
func reset() -> void:
	super.reset()
	tick_count = 0
	accumulated_delta = 0.0
