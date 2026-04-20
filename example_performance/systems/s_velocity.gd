class_name VelocitySystem
extends System

## How often off-screen entities update their position (seconds).
## Lower = smoother off-screen movement but more transform cost.
@export var offscreen_tick_interval: float = 0.2

var _offscreen_timer: SystemTimer

func setup():
	safe_iteration = false
	_offscreen_timer = SystemTimer.new()
	_offscreen_timer.interval = offscreen_tick_interval


func sub_systems() -> Array[Array]:
	return [
		[q.with_all([C_Velocity]).enabled().iterate([C_Velocity]), process_onscreen],
		[q.with_all([C_Velocity]).disabled().iterate([C_Velocity]), process_offscreen, _offscreen_timer],
	]


## On-screen: full-rate transform updates every frame
func process_onscreen(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]
	for i in entities.size():
		var velocity = velocities[i]
		if velocity:
			var val = velocity.velocity * delta
			entities[i].position += val
			entities[i].rotation += val


## Off-screen: reduced-rate updates to save transform notification cost.
## Applies the full interval's worth of movement so entities move at the same speed.
func process_offscreen(entities: Array[Entity], components: Array, _delta: float) -> void:
	var effective_delta = _offscreen_timer.interval
	var velocities = components[0]
	for i in entities.size():
		var velocity = velocities[i]
		if velocity:
			var val = velocity.velocity * effective_delta
			entities[i].position += val
			entities[i].rotation += val
