class_name VelocitySystem
extends System

var path = C_Velocity.resource_path

func query() -> QueryBuilder:
	return q.with_all([C_Velocity])
	

func process_all(entities: Array, delta: float) -> bool:
	for entity in entities:
		var c_velocity := entity.components.get(path, null) as C_Velocity
		# Update the entity's position based on its velocity
		var position: Vector3 = entity.transform.origin
		position += c_velocity.velocity * delta
		entity.transform.origin = position
	return true # Return true to indicate processing was successful
