class_name VelocitySystem
extends System

var path = C_Velocity.resource_path

func query() -> QueryBuilder:
	return q.with_all([C_Velocity]).enabled()


func process_all(entities: Array, delta: float):
	for entity in entities:
		call_thread_safe('_move_entity', entity, delta)


func _move_entity(entity: Entity, delta: float):
	var c_velocity := entity.components.get(path, null) as C_Velocity
	# Update the entity's position based on its velocity
	var position: Vector3 = entity.transform.origin
	position += c_velocity.velocity * delta
	entity.transform.origin = position
