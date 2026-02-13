class_name ExampleMiddleware
extends RefCounted
## Middleware layer for the network example.
## Connects to NetworkSync signals and applies visual properties to spawned entities.
## This demonstrates the three-layer architecture:
##   Addon (NetworkSync) -> Middleware (this) -> Game code

var network_sync: NetworkSync


func _init(p_network_sync: NetworkSync) -> void:
	network_sync = p_network_sync
	# Connect to entity_spawned signal - fired after spawn RPC is received (for remote entities)
	network_sync.entity_spawned.connect(_on_entity_spawned)
	# Connect to local_player_spawned signal - fired when local player is spawned
	network_sync.local_player_spawned.connect(_on_entity_spawned)
	# Connect to world.entity_added for HOST-spawned entities (projectiles, etc.)
	# Use call_deferred so component values are set before we apply visuals
	ECS.world.entity_added.connect(_on_entity_added_deferred)


func _on_entity_spawned(entity: Entity) -> void:
	apply_visuals(entity)


func _on_entity_added_deferred(entity: Entity) -> void:
	# Defer so component values are set (they're assigned after add_entity)
	# Use callable to capture entity reference
	(func(): apply_visuals(entity)).call_deferred()


## Apply visual properties based on entity components.
## Called automatically for RPC-received entities, and manually for HOST-spawned entities.
func apply_visuals(entity: Entity) -> void:
	_apply_position(entity)
	_apply_projectile_visual(entity)
	_apply_player_visual(entity)


func _apply_position(entity: Entity) -> void:
	# Apply position component to Node3D
	var position_comp = entity.get_component(C_NetPosition)
	if not position_comp:
		return

	if entity is Entity:
		entity.global_position = position_comp.position


func _apply_projectile_visual(entity: Entity) -> void:
	var projectile = entity.get_component(C_Projectile)
	if not projectile:
		return

	var visual = entity.get_node_or_null("Visual") as CSGSphere3D
	if not visual:
		return

	var color: Color = projectile.projectile_color
	if color == Color.WHITE:
		return  # Default color, no override needed

	# Create material with color and emission
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.5
	visual.material = material


func _apply_player_visual(entity: Entity) -> void:
	# Only apply to player entities
	if not entity.has_component(C_PlayerInput):
		return

	var player_num = entity.get_component(C_PlayerNumber)
	if not player_num:
		return

	var visual = entity.get_node_or_null("Visual") as CSGBox3D
	if not visual:
		return

	# Apply color based on player_number (join order: 1-4)
	# 1=Blue, 2=Red, 3=Green, 4=Yellow
	var color := _get_player_color(player_num.player_number)
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	visual.material = material


func _get_player_color(player_number: int) -> Color:
	match player_number:
		1: return Color.CORNFLOWER_BLUE
		2: return Color.INDIAN_RED
		3: return Color.MEDIUM_SEA_GREEN
		4: return Color.GOLD
		_: return Color.WHITE  # Fallback for unexpected player numbers
