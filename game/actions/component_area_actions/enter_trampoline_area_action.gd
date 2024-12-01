class_name EnterTrampolineAreaAction
extends ComponentAreaAction


# if it's the player let them on the trampoline
func on_enter(trampoline: Entity, player: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if not player is Player:
		return
	# lerp the player to the center of the trampoline
	# add the bounce component to the player
	# remove the player movement control
	# add the trampoline movement control

func on_exit(trampoline: Entity, player: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if not player is Player:
		return
	
	