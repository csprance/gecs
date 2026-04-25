class_name SimpleRandomVelocitySystem
extends System

## Interval between velocity perturbations, in seconds. Drives a SystemTimer so
## the system only runs at this rate — removing the per-entity C_Timer
## bookkeeping the old implementation needed to gate work on frame-time.
@export var time_between_updates: float = 0.1


func setup():
	safe_iteration = false
	set_tick_rate(time_between_updates)


func query() -> QueryBuilder:
	return q.with_all([C_Velocity]).iterate([C_Velocity])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var velocities = components[0]
	for i in entities.size():
		velocities[i].velocity += Vector3(
			randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)
		)
