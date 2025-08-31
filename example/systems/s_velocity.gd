class_name VelocitySystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity])
	

func process_all(entities: Array, delta: float) -> bool:
	var c_velocitys = ECS.get_components(entities, C_Velocity) as Array[C_Velocity]
	for i in range(entities.size()):
		var entity = entities[i]
		var c_velocity := c_velocitys[i] as C_Velocity
		
		# Update the entity's position based on its velocity
		var position: Vector3 = entity.transform.origin
		position += c_velocity.velocity * delta
		entity.transform.origin = position
	return true # Return true to indicate processing was successful
