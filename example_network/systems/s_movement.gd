class_name S_NetworkMovement
extends System
## Movement system - applies velocity to entity position.
## Processes entities with CN_LocalAuthority (local simulation).
## Remote entities receive position updates via native MultiplayerSynchronizer.
## Registers a custom receive handler for C_NetVelocity to blend corrections.

const MOVE_SPEED := 5.0
const ARENA_BOUND := 4.5 # Half of 10x10 arena minus player size


func setup() -> void:
	# Register a blend-correction receive handler for C_NetVelocity.
	# When the server sends a velocity correction, we lerp instead of snapping
	# so local movement feels smooth even under reconciliation.
	# setup() is deferred until ECS.world is assigned, so get_node() is safe here.
	var ns := ECS.world.get_node("NetworkSync") as NetworkSync
	if ns == null:
		return
	ns.register_receive_handler("C_NetVelocity", _blend_velocity_correction)


func _blend_velocity_correction(entity: Entity, comp: Component, props: Dictionary) -> bool:
	# Only blend on entities we have local authority over; let server apply others directly.
	if not entity.has_component(CN_LocalAuthority):
		return false
	if props.has("direction"):
		var c := comp as C_NetVelocity
		c.direction = c.direction.lerp(props["direction"], 0.3)
	return true


func query() -> QueryBuilder:
	# Only move local entities - remote positions come from network sync
	return q.with_all([C_NetVelocity, C_PlayerInput, CN_LocalAuthority]).iterate([C_NetVelocity, C_PlayerInput])


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
