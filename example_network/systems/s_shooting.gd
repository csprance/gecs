class_name S_NetworkShooting
extends System
## Shooting system - spawns projectiles when player shoots.
## SERVER-ONLY spawning for spawn-only sync pattern.
## Clients do NOT spawn projectiles - they receive spawn RPCs from server.

var _projectile_scene: PackedScene = preload("res://example_network/entities/e_projectile.tscn")
var _cooldown_tracker: Dictionary = {}  # entity_id -> time_since_shot

const FIRE_RATE := 0.3  # Seconds between shots
const PROJECTILE_SPEED := 10.0


func query() -> QueryBuilder:
	return q.with_all([C_PlayerInput, C_PlayerNumber]).iterate([C_PlayerInput, C_PlayerNumber])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var inputs = components[0]
	var player_numbers = components[1]

	# Determine if we're in multiplayer and if we're the server
	var mp = ECS.world.get_tree().get_multiplayer()
	var is_in_multiplayer = mp.has_multiplayer_peer()
	var is_server = mp.is_server() if is_in_multiplayer else true

	for i in entities.size():
		var entity = entities[i]
		var player_input = inputs[i] as C_PlayerInput
		var player_num = player_numbers[i] as C_PlayerNumber

		# Update cooldown
		var cooldown = _cooldown_tracker.get(entity.id, FIRE_RATE)
		cooldown += delta
		_cooldown_tracker[entity.id] = cooldown

		# Check if shooting
		if not player_input.is_shooting:
			continue

		# Check cooldown
		if cooldown < FIRE_RATE:
			continue

		# In multiplayer: only server spawns (spawn-only sync pattern)
		# Clients will receive the spawn via RPC from NetworkSync
		if is_in_multiplayer and not is_server:
			continue

		# Spawn projectile
		_spawn_projectile(entity, player_input.shoot_direction, player_num.player_number)
		_cooldown_tracker[entity.id] = 0.0


func _spawn_projectile(shooter: Entity, direction: Vector3, player_number: int) -> void:
	var projectile = _projectile_scene.instantiate() as Entity

	# Get spawn position (in front of shooter, slightly elevated)
	var shoot_dir = direction if direction.length() > 0.1 else Vector3.FORWARD
	var spawn_pos = shooter.global_position + shoot_dir * 1.0 + Vector3(0, 0.8, 0)

	# Add to scene tree first
	var entities_node = ECS.world.get_node("Entities")
	entities_node.add_child(projectile)
	projectile.global_position = spawn_pos

	# Add to ECS world - this triggers NetworkSync to queue spawn broadcast
	ECS.world.add_entity(projectile)

	# CRITICAL: Set component values AFTER add_entity()
	# NetworkSync captures these via call_deferred and includes them in spawn RPC
	var position_comp = projectile.get_component(C_NetPosition) as C_NetPosition
	if position_comp:
		position_comp.position = spawn_pos

	var velocity = projectile.get_component(C_NetVelocity) as C_NetVelocity
	if velocity:
		velocity.direction = shoot_dir * PROJECTILE_SPEED

	var proj_comp = projectile.get_component(C_Projectile) as C_Projectile
	if proj_comp:
		proj_comp.projectile_color = _get_player_color(player_number)


func _get_player_color(player_number: int) -> Color:
	# Fixed color rotation: Blue, Red, Green, Yellow (max 4 players)
	match player_number:
		1: return Color.CORNFLOWER_BLUE
		2: return Color.INDIAN_RED
		3: return Color.MEDIUM_SEA_GREEN
		4: return Color.GOLD
		_: return Color.WHITE
