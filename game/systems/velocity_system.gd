class_name VelocitySystem
extends System

func on_process_entity(entity: Entity, delta: float):
	var velocity: Velocity = entity.get_component("velocity")
	var transform: Transform = entity.get_component("transform")
	
	# Calculate velocity as a vector and apply movement
	var velocity_vector = velocity.direction.normalized() * velocity.speed
	transform.position += velocity_vector * delta
