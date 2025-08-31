class_name VelocitySystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity])
	

func process_all(entities: Array, delta: float) -> bool:
	for entity in entities:
		var velocity_component: C_Velocity = entity.get_component(C_Velocity)
		# Update the entity's position based on its velocity
		var position: Vector3 = entity.transform.origin
		position += velocity_component.velocity * delta
		entity.transform.origin = position
	return true # Return true to indicate processing was successful
