class_name ExitLevelAreaAction
extends ComponentAreaAction


func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_Player])

# Start attacking the body if we get in the attack area
func _on_enter(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	Loggie.debug('Exiting Level', body)
	# Purge the world and then move to the main menu
	var world = World.new()
	ECS.world.purge()
	ECS.world = world
	
