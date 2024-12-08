## If the entity is a player or a victim make the parent start chasing the entity
class_name ChaseInAreaAreaAction
extends ComponentAreaAction

func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_Player, C_Victim])

# Start chaing the body if they get in the interest area
func _on_enter(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	Loggie.debug('Started Chasing', body)
	parent.add_relationship(Relationship.new(C_IsChasing.new(), body))

# Stop chasing the body if they get out of the interest area and become interested in the last position
func _on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if parent.has_relationship(Relationships.chasing_anything()):
		parent.remove_relationship(Relationships.chasing_anything())
		Loggie.debug('Interested in position now', body.global_transform.origin)
		parent.add_component(C_Interested.new(body.global_transform.origin))
		parent.add_component(C_LookAt.new(body.global_transform.origin))