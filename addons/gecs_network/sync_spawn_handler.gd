extends RefCounted
## Entity spawn/despawn: serialization, world state sync, component add/remove over network.
##
## Internal helper for NetworkSync. No class_name - not part of public API.

var _ns  # NetworkSync reference (untyped to avoid circular deps)


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# WORLD STATE SYNC (Late Join)
# ============================================================================


func serialize_world_state() -> Dictionary:
	var entities_data: Array[Dictionary] = []

	for entity in _ns._world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue  # Skip non-networked entities

		entities_data.append(serialize_entity_spawn(entity))

	# Include session_id so client can sync their session tracking
	return {"entities": entities_data, "session_id": _ns._game_session_id}


func handle_sync_world_state(state: Dictionary) -> void:
	# CRITICAL: Sync session ID from server FIRST before processing entities
	# Otherwise client's session_id (0) won't match server's, causing all spawns to be rejected
	var server_session_id = state.get("session_id", 0)
	if server_session_id != _ns._game_session_id:
		print(
			(
				"[SESSION-SYNC] Updating client session_id: %d -> %d"
				% [_ns._game_session_id, server_session_id]
			)
		)
		_ns._game_session_id = server_session_id

	if _ns.debug_logging:
		print(
			(
				"Received world state with %d entities (session_id: %d)"
				% [state.get("entities", []).size(), _ns._game_session_id]
			)
		)

	var entities_data = state.get("entities", [])
	for entity_data in entities_data:
		handle_spawn_entity(entity_data)


# ============================================================================
# ENTITY SPAWN BROADCAST
# ============================================================================


## Broadcast entity spawn to all clients (called deferred to allow component setup)
func broadcast_entity_spawn(entity: Entity, entity_id: String) -> void:
	# Validate entity still exists (may have been removed before deferred call)
	if not is_instance_valid(entity):
		_ns._broadcast_pending.erase(entity_id)
		return

	# Check if spawn was cancelled (entity removed before broadcast)
	# _on_entity_removed erases from _broadcast_pending when entity is removed early
	if not _ns._broadcast_pending.has(entity_id):
		return  # Spawn was cancelled, don't broadcast

	# Clear pending flag (must be done even if we return early)
	_ns._broadcast_pending.erase(entity_id)

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return

	# Serialize and broadcast spawn (now with correct component values)
	var spawn_data = serialize_entity_spawn(entity)

	# DIAGNOSTIC: Always log spawn broadcasts for tracking desync issues
	var transform_pos = "N/A"
	var transform_comp_name = _ns.sync_config.transform_component
	if transform_comp_name != "" and spawn_data.get("components", {}).has(transform_comp_name):
		var t_data = spawn_data["components"][transform_comp_name]
		if t_data.has("position"):
			transform_pos = str(t_data["position"])
	if _ns.debug_logging:
		print(
			(
				"[SPAWN-TRACK] SERVER BROADCAST: entity=%s, name=%s, session=%d, position=%s"
				% [entity_id, entity.name, _ns._game_session_id, transform_pos]
			)
		)

	_ns._spawn_entity.rpc(spawn_data)


# ============================================================================
# ENTITY SPAWN/DESPAWN HANDLING (from RPC)
# ============================================================================


func handle_spawn_entity(data: Dictionary) -> void:
	var entity_id = data.get("id", "")
	var entity_name = data.get("name", "")  # Server's entity name for consistent naming
	var scene_path = data.get("scene_path", "")
	var session_id = data.get("session_id", 0)

	# DIAGNOSTIC: Always log spawn RPC receipt for tracking desync issues
	var my_peer_id = _ns.net_adapter.get_my_peer_id()
	var is_server = _ns.net_adapter.is_server()
	var prefix = "SERVER" if is_server else "CLIENT"

	# For server, this is called via world state serialization (not RPC), so session should match
	# For clients, this is called via RPC and session mismatch means stale spawn
	if _ns.debug_logging:
		print(
			(
				"[SPAWN-TRACK] %s %d RECEIVED: entity=%s, name=%s, session=%d (local=%d)"
				% [prefix, my_peer_id, entity_id, entity_name, session_id, _ns._game_session_id]
			)
		)

	# Ignore stale spawn RPCs from previous game sessions
	if session_id != _ns._game_session_id:
		if _ns.debug_logging:
			print(
				(
					"[SPAWN-TRACK] %s %d REJECTED (stale): entity=%s (session %d != local %d)"
					% [prefix, my_peer_id, entity_id, session_id, _ns._game_session_id]
				)
			)
		return

	if entity_id == "":
		print("Received spawn with empty entity ID")
		return

	# Validate scene path
	if scene_path != "" and not validate_entity_spawn(scene_path):
		return

	# Check if entity already exists
	if _ns._world.entity_id_registry.has(entity_id):
		if _ns.debug_logging:
			print("Entity already exists, updating: %s" % entity_id)
		var existing = _ns._world.entity_id_registry[entity_id]
		_ns._apply_component_data(existing, data.get("components", {}))
		return

	# Instantiate entity from scene path
	var entity: Entity

	if scene_path != "":
		# validate_entity_spawn already checks res:// prefix and ResourceLoader.exists
		var scene = load(scene_path)
		if scene:
			entity = scene.instantiate()
		else:
			print("Failed to load scene: %s" % scene_path)
			return
	else:
		entity = Entity.new()

	entity.id = entity_id

	# Extract peer_id from serialized CN_NetworkIdentity and set up multiplayer authority
	# BEFORE adding to world. This is critical for MultiplayerSynchronizer to work correctly.
	var components_data = data.get("components", {})
	var peer_id_for_name = 0
	if components_data.has("CN_NetworkIdentity"):
		var net_id_data = components_data["CN_NetworkIdentity"]
		var peer_id = net_id_data.get("peer_id", 0)
		if peer_id > 0:
			# Player-owned: authority is the owning peer
			peer_id_for_name = peer_id
			entity.set_multiplayer_authority(peer_id)
			# If entity has owner_peer_id property, set it to match multiplayer authority
			# (used by player entity classes in on_ready() to create CN_NetworkIdentity)
			if "owner_peer_id" in entity:
				entity.set("owner_peer_id", peer_id)
			if _ns.debug_logging:
				print("Set multiplayer authority to %d for entity %s" % [peer_id, entity_id])
		else:
			# Server-owned (peer_id=0): authority is always server (peer_id=1)
			# This is critical for enemies, pickups, and other server-controlled entities
			entity.set_multiplayer_authority(1)
			if _ns.debug_logging:
				print(
					"Set multiplayer authority to 1 (server) for server-owned entity %s" % entity_id
				)

	# Set entity name - must match server for MultiplayerSynchronizer node paths to work
	# For players: use peer_id so _enter_tree() parses it correctly
	# For server-owned entities: use server's entity name (e.g., "Enemy_12345")
	if peer_id_for_name > 0:
		entity.name = str(peer_id_for_name)
	elif entity_name != "":
		entity.name = entity_name  # Use server's name for consistent node paths
	else:
		entity.name = entity_id  # Fallback to UUID if no name provided

	# Add to world (World.add_entity adds to scene tree via entity_nodes_root)
	# This triggers _initialize() -> define_components() -> on_ready()
	_ns._world.add_entity(entity)

	# Apply initial component data AFTER define_components has run
	# This updates the components with server's authoritative values
	_ns._apply_component_data(entity, components_data)

	# Add any components from spawn data that don't exist on the entity.
	# This handles cases where the server added components (like C_Dying) after
	# define_components() but before the deferred spawn broadcast.
	var script_paths = data.get("script_paths", {})
	for comp_type in components_data.keys():
		if _ns._find_component_by_type(entity, comp_type):
			continue  # Already exists
		if not script_paths.has(comp_type):
			continue  # No script path to instantiate from

		var script_path = script_paths[comp_type]

		# Validate script path before loading (security: prevent arbitrary resource loading)
		if not script_path.begins_with("res://"):
			push_warning("Invalid script path (must start with res://): %s" % script_path)
			continue
		if not ResourceLoader.exists(script_path):
			push_warning("Script path does not exist: %s" % script_path)
			continue

		var script = load(script_path)
		if not script:
			continue
		var new_comp = script.new()
		_ns._applying_network_data = true
		entity.add_component(new_comp)
		_ns._applying_network_data = false
		# Apply the serialized property data to the new component
		_ns._apply_component_data(entity, {comp_type: components_data[comp_type]})
		if _ns.debug_logging:
			print(
				"[SPAWN] Added missing component %s to %s from spawn data" % [comp_type, entity_id]
			)

	# Debug: log received position
	if _ns.debug_logging:
		var recv_pos = "N/A"
		var transform_comp_name = _ns.sync_config.transform_component
		if transform_comp_name != "" and components_data.has(transform_comp_name):
			var t_data = components_data[transform_comp_name]
			if t_data.has("position"):
				recv_pos = str(t_data["position"])
		var applied_pos = "N/A"
		if transform_comp_name != "":
			var t_comp = _ns._find_component_by_type(entity, transform_comp_name)
			if t_comp and "position" in t_comp:
				applied_pos = str(t_comp.position)
		print(
			(
				"CLIENT: Spawn %s - received pos: %s, applied %s.position: %s"
				% [entity_name, recv_pos, transform_comp_name, applied_pos]
			)
		)

	# Sync Node3D position from transform component to prevent spawning at origin.
	# This is critical for spawn-only entities (projectiles) that don't use CN_SyncEntity.
	if entity is Entity and _ns.sync_config.transform_component != "":
		var transform_comp = _ns._find_component_by_type(
			entity, _ns.sync_config.transform_component
		)
		if transform_comp and "position" in transform_comp:
			entity.global_position = transform_comp.get("position")

	# CRITICAL: For entities with CN_SyncEntity, synchronously instantiate model and create
	# MultiplayerSynchronizer BEFORE the server's sync data arrives. Without this, Godot's
	# multiplayer system can't find the target node and produces "Node not found" errors.
	#
	# Note: _auto_assign_markers is still called via _on_entity_added signal handler.
	# But we must set up native sync synchronously here to avoid timing race.
	if entity.has_component(CN_SyncEntity):
		# Instantiate model synchronously (creates CharacterBody3D, sets up references)
		var model_created = _ns._native_handler.sync_instantiate_model(entity)
		if model_created or entity.get_component(CN_SyncEntity).target_node != null:
			# Model exists (either just created or already had target_node set)
			# Now create MultiplayerSynchronizer immediately
			_ns._native_handler.auto_setup_native_sync(entity)
		elif _ns.debug_logging:
			print(
				(
					"[NetworkSync] Warning: Entity %s has CN_SyncEntity but no model - sync may fail"
					% entity.name
				)
			)

	# Apply relationships from spawn data
	var rel_data = data.get("relationships", [])
	if not rel_data.is_empty():
		_ns._relationship_handler.apply_entity_relationships(entity, rel_data)

	# Emit signal for projects to do post-spawn setup (e.g., apply visual properties)
	_ns.entity_spawned.emit(entity)

	# Always log successful spawns for tracking
	if _ns.debug_logging:
		print(
			(
				"[SPAWN-TRACK] %s %d SPAWN SUCCESS: entity=%s, name=%s, session=%d"
				% [prefix, my_peer_id, entity_id, entity_name, session_id]
			)
		)

	# Check if this is the local player and emit signal for UI setup
	var net_id = entity.get_component(CN_NetworkIdentity) as CN_NetworkIdentity
	if net_id and net_id.is_local(_ns.net_adapter):
		if _ns.debug_logging:
			print(
				(
					"CLIENT: Local player entity spawned: %s (peer_id: %d)"
					% [entity_id, net_id.peer_id]
				)
			)
		_ns.local_player_spawned.emit(entity)
	elif net_id:
		if _ns.debug_logging:
			print(
				(
					"CLIENT: Remote player entity spawned: %s (owner peer_id: %d)"
					% [entity_id, net_id.peer_id]
				)
			)


func handle_despawn_entity(entity_id: String, session_id: int = 0) -> void:
	# DIAGNOSTIC: Always log despawn RPC receipt for tracking desync issues
	var my_peer_id = _ns.net_adapter.get_my_peer_id()
	var is_server = _ns.net_adapter.is_server()
	var prefix = "SERVER" if is_server else "CLIENT"

	if _ns.debug_logging:
		print(
			(
				"[SPAWN-TRACK] %s %d DESPAWN RECEIVED: entity=%s, session=%d (local=%d)"
				% [prefix, my_peer_id, entity_id, session_id, _ns._game_session_id]
			)
		)

	# Ignore stale despawn RPCs from previous game sessions
	if session_id != _ns._game_session_id:
		if _ns.debug_logging:
			print(
				(
					"[SPAWN-TRACK] %s %d DESPAWN REJECTED (stale): entity=%s (session %d != local %d)"
					% [prefix, my_peer_id, entity_id, session_id, _ns._game_session_id]
				)
			)
		return

	var entity = _ns._world.entity_id_registry.get(entity_id)
	if entity:
		if _ns.debug_logging:
			print(
				(
					"[SPAWN-TRACK] %s %d DESPAWN APPLIED: entity=%s, name=%s"
					% [prefix, my_peer_id, entity_id, entity.name]
				)
			)
		_ns._world.remove_entity(entity)
		# Free the node from scene tree (remove_entity only removes from ECS world)
		if is_instance_valid(entity):
			entity.queue_free()
	else:
		print(
			(
				"[SPAWN-TRACK] %s %d DESPAWN SKIPPED (not found): entity=%s"
				% [prefix, my_peer_id, entity_id]
			)
		)


# ============================================================================
# COMPONENT ADD/REMOVE OVER NETWORK (from RPC)
# ============================================================================


func handle_add_component(
	entity_id: String,
	comp_type: String,
	script_path: String,
	comp_data: Dictionary,
	session_id: int = 0
) -> void:
	# Reject stale RPCs from previous game sessions
	if session_id != _ns._game_session_id:
		if _ns.debug_logging:
			print(
				"[ADD-COMP] Rejected stale session: %d != %d" % [session_id, _ns._game_session_id]
			)
		return

	var sender_id = _ns.net_adapter.get_remote_sender_id()

	var entity = _ns._world.entity_id_registry.get(entity_id)
	if not entity:
		if _ns.debug_logging:
			print("Received component addition for unknown entity: %s" % entity_id)
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return

	# Validation: Only accept from authorized sources
	if _ns.net_adapter.is_server():
		# Server accepts from entity owner only
		if net_id.peer_id != sender_id:
			if _ns.debug_logging:
				print(
					(
						"Rejected component addition from peer %d for entity owned by peer %d"
						% [sender_id, net_id.peer_id]
					)
				)
			return
		# Relay to all clients
		_ns._add_component.rpc(entity_id, comp_type, script_path, comp_data, session_id)
	else:
		# Client accepts from server only
		if sender_id != 1:
			if _ns.debug_logging:
				print("Rejected component addition from non-server peer %d" % sender_id)
			return
		# Skip if this is our own entity
		if net_id.is_local(_ns.net_adapter):
			return

	# Skip if component already exists
	if _ns._find_component_by_type(entity, comp_type):
		return

	# Validate script path before loading (security: prevent arbitrary resource loading)
	if not script_path.begins_with("res://"):
		push_warning("[NetworkSync] Invalid script path (must start with res://): %s" % script_path)
		return
	if not ResourceLoader.exists(script_path):
		push_warning("[NetworkSync] Script not found: %s" % script_path)
		return

	# Instantiate from script path
	var script = load(script_path)
	if not script:
		if _ns.debug_logging:
			print("Failed to load script for component: %s" % script_path)
		return

	var new_component = script.new()

	# Add with sync loop prevention
	_ns._applying_network_data = true
	entity.add_component(new_component)
	_ns._applying_network_data = false

	# Apply serialized property data
	if not comp_data.is_empty():
		_ns._apply_component_data(entity, {comp_type: comp_data})

	if _ns.debug_logging:
		print("Added component %s to entity %s" % [comp_type, entity_id])


func handle_remove_component(entity_id: String, comp_type: String) -> void:
	var sender_id = _ns.net_adapter.get_remote_sender_id()

	var entity = _ns._world.entity_id_registry.get(entity_id)
	if not entity:
		if _ns.debug_logging:
			print("Received component removal for unknown entity: %s" % entity_id)
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return

	# Validation: Only accept from authorized sources
	if _ns.net_adapter.is_server():
		# Server accepts from entity owner only
		if net_id.peer_id != sender_id:
			if _ns.debug_logging:
				print(
					(
						"Rejected component removal from peer %d for entity owned by peer %d"
						% [sender_id, net_id.peer_id]
					)
				)
			return
		# Relay to all clients
		_ns._remove_component.rpc(entity_id, comp_type)
	else:
		# Client accepts from server only
		if sender_id != 1:
			if _ns.debug_logging:
				print("Rejected component removal from non-server peer %d" % sender_id)
			return
		# Skip if this is our own entity
		if net_id.is_local(_ns.net_adapter):
			return

	# Find and remove the component
	var component = _ns._find_component_by_type(entity, comp_type)
	if component:
		# Set flag to prevent sync loops
		_ns._applying_network_data = true
		entity.remove_component(component)
		_ns._applying_network_data = false
		if _ns.debug_logging:
			print("Removed component %s from entity %s" % [comp_type, entity_id])


# ============================================================================
# SERIALIZATION HELPERS
# ============================================================================


func serialize_entity_spawn(entity: Entity) -> Dictionary:
	var components_data = {}
	var script_paths = {}

	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		var script = comp.get_script()

		# Null guard: handle components without scripts (use class name as fallback)
		var comp_type: String
		if script == null:
			comp_type = comp.get_class()
		else:
			comp_type = script.get_global_name()
			# Fallback to filename if class_name not declared
			if comp_type == "":
				comp_type = script.resource_path.get_file().get_basename()

		# Skip model_ready_component (e.g., C_Instantiated) - clients must instantiate models locally
		# If this component is synced, clients will have C_Instantiated before S_ModelInstantiation
		# runs, causing the model to never be instantiated on clients
		if comp_type == _ns.sync_config.model_ready_component:
			continue

		# NOTE: Do NOT skip skip_component_types here - those are skipped for continuous sync
		# but we DO need their initial values at spawn (e.g., C_Transform for position)

		components_data[comp_type] = comp.serialize()
		# Only add script path if script exists
		if script != null and script.resource_path != "":
			script_paths[comp_type] = script.resource_path

	var result = {
		"id": entity.id,
		"name": entity.name,  # Include entity name for consistent naming across peers
		"scene_path": entity.scene_file_path,
		"components": components_data,
		"script_paths": script_paths,  # Script paths for adding missing components on clients
		"session_id": _ns._game_session_id  # Prevent stale spawns after game reset
	}

	# Include relationships if sync is enabled
	var relationships = _ns._relationship_handler.serialize_entity_relationships(entity)
	if not relationships.is_empty():
		result["relationships"] = relationships

	return result


func validate_entity_spawn(scene_path: String) -> bool:
	# Empty scene path means Entity.new() - always allowed
	if scene_path == "":
		return true

	if not scene_path.begins_with("res://"):
		push_warning("[NetworkSync] Invalid scene path (must start with res://): %s" % scene_path)
		return false

	# Check if scene exists
	if not ResourceLoader.exists(scene_path):
		print("Invalid scene path for spawn: %s" % scene_path)
		return false

	return true
