class_name AttackInAreaAction
extends ComponentAreaAction

func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_Player, C_Victim])

# Start attacking the body if we get in the attack area
func on_enter(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	Loggie.debug('Started Attacking', body)
	# parent.add_component(C_Attacking.new(body))
	parent.add_relationship(Relationship.new(C_IsAttacking.new(), body))

# Stop attacking the body if we get out of the attack area
func on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if body is Player:
		Loggie.debug('Stopped Attacking', body)
		# parent.remove_component(C_Attacking)
		parent.remove_relationship(Relationship.new(C_IsAttacking.new(), body))

