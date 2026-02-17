class_name S_NetworkMovement
extends System
## Movement system - applies velocity to entity position.
## Processes entities with CN_LocalAuthority (local simulation).
## Remote entities receive position updates via native MultiplayerSynchronizer.

const MOVE_SPEED := 5.0
const ARENA_BOUND := 4.5  # Half of 10x10 arena minus player size


func query() -> QueryBuilder:
	# Only move local entities - remote positions come from network sync
	return q.with_all([C_NetVelocity, C_PlayerInput, CN_LocalAuthority, CN_NetworkIdentity]).iterate([C_NetVelocity, C_PlayerInput, CN_NetworkIdentity])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]
	var inputs = components[1]
	var net_ids = components[2]
	for i in entities.size():
		var entity = entities[i]
		var velocity = velocities[i] as C_NetVelocity
		var player_input = inputs[i] as C_PlayerInput
		var net_id = net_ids[i] as CN_NetworkIdentity

		# Only move entities we own
		if net_id and not net_id.is_local():
			continue

		# Calculate velocity from input
		var move_input = player_input.move_direction
		velocity.direction = Vector3(move_input.x, 0, move_input.y) * MOVE_SPEED

		# Apply velocity to position (skip when stationary to avoid unnecessary transform updates)
		if velocity.direction != Vector3.ZERO and entity is Node3D:
			var new_pos = entity.global_position + velocity.direction * delta
			new_pos.x = clampf(new_pos.x, -ARENA_BOUND, ARENA_BOUND)
			new_pos.z = clampf(new_pos.z, -ARENA_BOUND, ARENA_BOUND)
			entity.global_position = new_pos
