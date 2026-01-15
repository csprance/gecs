class_name ExampleMiddleware
extends RefCounted
## Middleware layer for the network example.
## Connects to NetworkSync signals and applies visual properties to spawned entities.
## This demonstrates the three-layer architecture:
##   Addon (NetworkSync) -> Middleware (this) -> Game code

var network_sync: NetworkSync


func _init(p_network_sync: NetworkSync) -> void:
	network_sync = p_network_sync
	# Connect to entity_spawned signal - fired after spawn RPC is received
	network_sync.entity_spawned.connect(_on_entity_spawned)


func _on_entity_spawned(entity: Entity) -> void:
	# Apply component data to entity node
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

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return

	var visual = entity.get_node_or_null("Visual") as CSGBox3D
	if not visual:
		return

	# Determine if this is the local player
	var mp = entity.get_tree().get_multiplayer()
	var local_peer_id = mp.get_unique_id() if mp.has_multiplayer_peer() else 1
	var is_local = net_id.peer_id == local_peer_id

	# Apply color: Blue for local, Red for remote
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CORNFLOWER_BLUE if is_local else Color.INDIAN_RED
	visual.material = material
