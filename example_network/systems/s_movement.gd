class_name S_NetworkMovement
extends System
## Movement system - applies velocity to entity position.
## Processes entities with C_LocalAuthority (local simulation).
## Remote entities receive position updates via native MultiplayerSynchronizer.

const MOVE_SPEED := 5.0
const ARENA_BOUND := 4.5  # Half of 10x10 arena minus player size


func query() -> QueryBuilder:
	# Only move local entities - remote positions come from network sync
	return q.with_all([C_NetVelocity, C_PlayerInput, C_LocalAuthority]).iterate([C_NetVelocity, C_PlayerInput])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]
	var inputs = components[1]

	for i in entities.size():
		var entity = entities[i]
		var velocity = velocities[i] as C_NetVelocity
		var player_input = inputs[i] as C_PlayerInput

		# Calculate velocity from input
		var move_input = player_input.move_direction
		velocity.direction = Vector3(move_input.x, 0, move_input.y) * MOVE_SPEED

		# Apply velocity to position
		if entity is Node3D:
			entity.global_position += velocity.direction * delta

			# Clamp to arena bounds
			entity.global_position.x = clamp(entity.global_position.x, -ARENA_BOUND, ARENA_BOUND)
			entity.global_position.z = clamp(entity.global_position.z, -ARENA_BOUND, ARENA_BOUND)
