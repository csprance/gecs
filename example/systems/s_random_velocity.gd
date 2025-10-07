class_name RandomVelocitySystem
extends System

@export var time_between_updates: float = 0.1 # Time in seconds between updates

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Timer])
	

func process_all(entities: Array, delta: float) -> bool:
	for entity in entities:
		# Check to see if we went over the time limit
		var c_timer = entity.get_component(C_Timer) as C_Timer
		c_timer.time += delta
		if c_timer.time <= time_between_updates:
			continue
		c_timer.time = 0.0

		# Randomly change the velocity
		var c_velocity = entity.get_component(C_Velocity) as C_Velocity
		c_velocity.velocity += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	
	return true
