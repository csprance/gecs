class_name S_NetworkInput
extends System
## Input system - reads keyboard input, updates C_PlayerInput.
## Only processes local player (entities with CN_LocalAuthority).


func query() -> QueryBuilder:
	# Only process entities we have local control over
	return q.with_all([C_PlayerInput, CN_LocalAuthority]).iterate([C_PlayerInput])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var inputs = components[0]

	for i in entities.size():
		var entity = entities[i]
		var player_input = inputs[i] as C_PlayerInput

		# Read movement input (Arrow keys or WASD via ui_* actions)
		var move_dir := Vector2.ZERO
		move_dir.x = Input.get_axis("ui_left", "ui_right")
		move_dir.y = Input.get_axis("ui_up", "ui_down")
		player_input.move_direction = move_dir.normalized() if move_dir.length() > 0.1 else Vector2.ZERO

		# Read shoot input (Space key via ui_accept)
		player_input.is_shooting = Input.is_action_pressed("ui_accept")

		# Update shoot direction based on last movement (or keep current)
		if move_dir.length() > 0.1:
			player_input.shoot_direction = Vector3(move_dir.x, 0, move_dir.y).normalized()
