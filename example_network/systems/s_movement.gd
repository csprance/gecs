## Movement system - applies velocity to entity position.
## Local entities: calculates velocity from input and moves directly.
## Remote entities: dead-reckons using synced velocity, with periodic position
## correction lerped smoothly from C_NetPosition updates (~20 Hz).
class_name S_NetworkMovement
extends System


const MOVE_SPEED := 5.0
const ARENA_BOUND := 4.5 # Half of 10x10 arena minus player size
## How fast remote entities correct toward the authoritative network position.
## Higher = snappier correction, lower = smoother but more drift.
const CORRECTION_SPEED := 10.0


func setup() -> void:
	# Register receive handlers for smooth remote entity interpolation.
	# setup() is deferred until ECS.world is assigned, so get_node() is safe here.
	var ns := ECS.world.get_node("NetworkSync") as NetworkSync
	if ns == null:
		return
	ns.register_receive_handler("C_NetVelocity", _on_receive_velocity)
	ns.register_receive_handler("C_NetPosition", _on_receive_position)


func _on_receive_velocity(entity: Entity, comp: Component, props: Dictionary) -> bool:
	# Local entities: blend velocity corrections so local movement stays smooth.
	# Remote entities: snap velocity so dead-reckoning uses the latest direction.
	if entity.has_component(CN_LocalAuthority):
		if props.has("direction"):
			var c := comp as C_NetVelocity
			c.direction = c.direction.lerp(props["direction"], 0.3)
		return true
	# Remote: let default handler apply directly (velocity drives dead-reckoning)
	return false


func _on_receive_position(entity: Entity, comp: Component, props: Dictionary) -> bool:
	# Local entities: don't override our authoritative position
	if entity.has_component(CN_LocalAuthority):
		return true
	# Remote entities: store the network position; process() will lerp toward it
	if props.has("position"):
		(comp as C_NetPosition).position = props["position"]
	return true


func query() -> QueryBuilder:
	# Process ALL entities with velocity and position - local AND remote
	return q.with_all([C_NetVelocity, C_PlayerInput, C_NetPosition]).iterate([C_NetVelocity, C_PlayerInput, C_NetPosition])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]
	var inputs = components[1]
	var positions = components[2]

	for i in entities.size():
		var entity = entities[i]
		var velocity = velocities[i] as C_NetVelocity
		var player_input = inputs[i] as C_PlayerInput
		var net_pos = positions[i] as C_NetPosition

		if entity.has_component(CN_LocalAuthority):
			_process_local(entity, velocity, player_input, net_pos, delta)
		else:
			_process_remote(entity, velocity, net_pos, delta)


func _process_local(entity: Entity, velocity: C_NetVelocity, player_input: C_PlayerInput, net_pos: C_NetPosition, delta: float) -> void:
	# Calculate velocity from input
	var move_input = player_input.move_direction
	velocity.direction = Vector3(move_input.x, 0, move_input.y) * MOVE_SPEED

	# Apply velocity to position
	if entity is Player:
		entity.global_position += velocity.direction * delta
		entity.global_position.x = clamp(entity.global_position.x, -ARENA_BOUND, ARENA_BOUND)
		entity.global_position.z = clamp(entity.global_position.z, -ARENA_BOUND, ARENA_BOUND)

		# Write authoritative position for outbound sync
		net_pos.position = entity.global_position


func _process_remote(entity: Entity, velocity: C_NetVelocity, net_pos: C_NetPosition, delta: float) -> void:
	if not (entity is Player):
		return

	# Dead-reckon: apply synced velocity for smooth per-frame movement
	entity.global_position += velocity.direction * delta

	# Correct toward authoritative network position to prevent drift
	entity.global_position = entity.global_position.lerp(net_pos.position, clamp(CORRECTION_SPEED * delta, 0.0, 1.0))

	# Clamp to arena bounds
	entity.global_position.x = clamp(entity.global_position.x, -ARENA_BOUND, ARENA_BOUND)
	entity.global_position.z = clamp(entity.global_position.z, -ARENA_BOUND, ARENA_BOUND)
