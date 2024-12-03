class_name KillOrSaveInAreaAction
extends ComponentAreaAction

func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_Player, C_Enemy])

# Start attacking the body if we get in the attack area
func on_enter(victim: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if body is Player:
		Loggie.debug('Saved!', body)
		victim.add_component(C_Saved.new())
	if body is Enemy:
		Loggie.debug('Killed!', body)
		victim.add_component(C_Death.new())
		


# Stop attacking the body if we get out of the attack area
func on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	pass
