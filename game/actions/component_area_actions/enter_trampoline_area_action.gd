class_name EnterTrampolineAreaAction
extends ComponentAreaAction


# if it's the player let them on the trampoline
func on_enter(trampoline: Entity, player: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
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

func on_exit(trampoline: Entity, player: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
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
	var c_tramp_trs = trampoline.get_component(C_Transform) as C_Transform
	player.remove_component(C_CharacterBody3D)
	var duration = 1.0  # Duration in seconds
	var elapsed_time = 0.0
	var start_position :Vector3= c_player_trs.transform.origin
	var target_position :Vector3 = trampoline.bounce_center.global_position
	print("EnterTrampolineAreaAction: move_to_center: start_position: ",start_position," target_position: ", target_position )
	while elapsed_time < duration:
		var t = elapsed_time / duration
		c_player_trs.transform.origin = start_position.lerp(target_position, t)
		print("EnterTrampolineAreaAction: move_to_center: c_player_trs.transform.origin: ",c_player_trs.transform.origin," start: ", start_position, " target: ", target_position, " t: ", t)
		await player.get_tree().process_frame
		elapsed_time += player.get_process_delta_time()
	# Ensure the player is exactly at the target position
	c_player_trs.transform.origin = target_position
	player.add_component(C_CharacterBody3D.new())