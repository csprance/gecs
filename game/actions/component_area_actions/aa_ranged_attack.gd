class_name RangedAttackInAreaAction
extends ComponentAreaAction

func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_Player])


# Start attacking the body if we get in the attack area
func _on_enter(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
		# if we're already dashing or in cool down don't dash
	if parent.has_component(C_Dashing) or parent.has_component(C_RangedAttackCooldown):
		return
	Loggie.debug('Started Range Attacking', body)
	# parent.add_component(C_Attacking.new(body))
	parent.add_relationship(Relationship.new(C_IsAttackingRanged.new(), body))
	await parent.get_tree().create_timer(2).timeout


# Stop attacking the body if we get out of the attack area
func _on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	Loggie.debug('Stopped Range Attacking', body)
	# parent.remove_component(C_Attacking)
	parent.remove_relationship(Relationship.new(C_IsAttackingRanged.new(), body))

