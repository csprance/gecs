class_name SimpleRandomVelocitySystem
extends System

@export var time_between_updates: float = 0.1


func setup():
	safe_iteration = false


func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Timer]).iterate([C_Velocity, C_Timer])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]
	var timers = components[1]

	for i in entities.size():
		var c_timer = timers[i]
		if c_timer == null:
			continue
		c_timer.time += delta
		if c_timer.time <= time_between_updates:
			continue
		c_timer.time = 0.0
		var c_velocity = velocities[i]
		if c_velocity != null:
			c_velocity.velocity += Vector3(
				randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)
			)
