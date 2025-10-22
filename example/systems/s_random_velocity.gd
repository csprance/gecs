class_name RandomVelocitySystem
extends System

@export var time_between_updates: float = 0.1 # Time in seconds between updates

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Timer]).enabled().iterate([C_Velocity, C_Timer])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0] # C_Velocity (first in iterate)
	var timers = components[1] # C_Timer (second in iterate)

	for i in entities.size():
		var c_timer = timers[i]
		if c_timer == null:
			continue

		# Check to see if we went over the time limit
		c_timer.time += delta
		if c_timer.time <= time_between_updates:
			continue
		c_timer.time = 0.0

		# Randomly change the velocity
		var c_velocity = velocities[i]
		if c_velocity != null:
			c_velocity.velocity += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
