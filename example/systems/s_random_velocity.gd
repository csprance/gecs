class_name RandomVelocitySystem
extends System

@export var time_between_updates: float = 0.1 # Time in seconds between updates

var velocity_path = C_Velocity.resource_path
var timer_path = C_Timer.resource_path

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Timer]).enabled()

## OPTIMIZED: Column-based iteration
func process_all(entities: Array, delta: float):
	for archetype in query().archetypes():
		var velocities = archetype.get_column(velocity_path)
		var timers = archetype.get_column(timer_path)

		for i in range(timers.size()):
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
