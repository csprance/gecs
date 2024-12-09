class_name EnterTrampolineAreaAction
extends ComponentAreaAction

func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_Player])

# if it's the player let them on the trampoline
func _on_enter(trampoline: Entity, player: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if not player is Player or not trampoline is Trampoline:
		assert(false, "EnterTrampolineAreaAction: on_enter: player is not a Player or trampoline is not a Trampoline")
		return
	# remove the player movement control
	player.remove_component(C_PlayerMovement)
	# Move the player to the center of the trampoline but over time and then return control back
	await move_to_center(trampoline, player)

	# add the bounce component to the player
	player.add_relationship(Relationship.new(C_BouncingOn.new(), trampoline))

	# add the trampoline movement control
	player.add_component(C_TrampolineControls.new())

func _on_exit(trampoline: Entity, player: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if not player is Player or not trampoline is Trampoline:
		assert(false, "EnterTrampolineAreaAction: on_exit: player is not a Player or trampoline is not a Trampoline")
		return
	# remove controls and relationship to trampoline
	player.remove_component(C_TrampolineControls)
	player.remove_relationship(Relationship.new(C_BouncingOn.new(), trampoline))
	# add player movement control back
	player.add_component(C_PlayerMovement.new())


func move_to_center(trampoline: Entity, player: Entity) -> void:
	var c_player_trs = player.get_component(C_Transform) as C_Transform
	var start_position = c_player_trs.transform.origin
	var end_position = trampoline.bounce_center.global_position
	player.remove_component(C_CharacterBody3D)
	var tween = player.create_tween()
	tween.tween_method(func(new_position): c_player_trs.transform.origin = new_position, start_position, end_position, 1.0)
	await tween.finished

