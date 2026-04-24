class_name SpawnManager
extends RefCounted
## Entity spawn/despawn manager: serialization, world state sync, and session-validated handlers.
##
## Encapsulates entity lifecycle logic for the GECS network module.
## Replaces sync_spawn_handler.gd with a clean v2 API (no SyncConfig, no RelationshipSync).
##
## Session safety: All spawn/despawn handlers reject data whose session_id does not
## match _ns._game_session_id, preventing stale RPC effects after game resets.

var _ns  # NetworkSync reference (untyped to avoid circular deps)


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# WORLD STATE SERIALIZATION (Late Join)
# ============================================================================


## Serialize all networked entities in the world.
## Returns {entities: Array[Dict], session_id: int}.
## Only entities with CN_NetworkIdentity are included.
func serialize_world_state() -> Dictionary:
	var entities_data: Array[Dictionary] = []

	for entity in _ns._world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue  # Skip non-networked entities
		entities_data.append(serialize_entity(entity))

	return {"entities": entities_data, "session_id": _ns._game_session_id}


# ============================================================================
# ENTITY SERIALIZATION
# ============================================================================


## Serialize a single entity to a Dictionary.
## Keys: id, name, scene_path, components (comp_type -> serialized data),
##       script_paths (comp_type -> resource_path), session_id.
func serialize_entity(entity: Entity) -> Dictionary:
	var components_data := {}
	var script_paths := {}

	for comp in entity.components.values():
		var script = comp.get_script()

		var comp_type: String
		if script == null:
			comp_type = comp.get_class()
		else:
			comp_type = script.get_global_name()
			if comp_type == "":
				comp_type = script.resource_path.get_file().get_basename()
				push_warning(
					"SpawnManager: Component without class_name: %s" % script.resource_path
				)

		components_data[comp_type] = comp.serialize()
		if script != null and script.resource_path != "":
			script_paths[comp_type] = script.resource_path

	var relationships: Array[Dictionary] = []
	if _ns.get("_relationship_handler") != null:
		relationships = _ns._relationship_handler.serialize_entity_relationships(entity)

	var result := {
		"id": entity.id,
		"name": entity.name,
		"scene_path": entity.scene_file_path,
		"components": components_data,
		"script_paths": script_paths,
		"relationships": relationships,
		"session_id": _ns._game_session_id,
	}
	var node_pos = entity.get("global_position")
	if node_pos != null:
		result["node_position"] = node_pos
		result["node_rotation"] = entity.get("global_rotation")
	return result


# ============================================================================
# SPAWN VALIDATION
# ============================================================================


## Validate a scene path before spawning.
## Returns true for empty paths (Entity.new() allowed), false for invalid paths.
func validate_entity_spawn(scene_path: String) -> bool:
	if scene_path == "":
		return true
	if not scene_path.begins_with("res://"):
		push_warning("[SpawnManager] Invalid scene path (must start with res://): %s" % scene_path)
		return false
	if not ResourceLoader.exists(scene_path):
		push_warning("[SpawnManager] Scene path does not exist: %s" % scene_path)
		return false
	return true


# ============================================================================
# SPAWN / DESPAWN HANDLERS (from RPC or world state sync)
# ============================================================================


## Handle an incoming spawn payload.
## Rejects silently if data["session_id"] != _ns._game_session_id.
## Adds entity to world BEFORE applying component data (Pitfall 6).
func handle_spawn_entity(data: Dictionary) -> void:
	var session_id = data.get("session_id", 0)

	# Reject stale spawns from previous game sessions
	if session_id != _ns._game_session_id:
		return

	var entity_id = data.get("id", "")
	if entity_id == "":
		return

	var scene_path = data.get("scene_path", "")
	if scene_path != "" and not validate_entity_spawn(scene_path):
		return

	# If entity already exists, update its components
	if _ns._world.entity_id_registry.has(entity_id):
		var existing = _ns._world.entity_id_registry[entity_id]
		_apply_component_data(existing, data)
		if _ns.get("_relationship_handler") != null:
			var rel_data = data.get("relationships", [])
			_ns._relationship_handler.apply_entity_relationships(existing, rel_data)
		return

	# Instantiate entity
	var entity: Entity
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		entity = scene.instantiate()
	else:
		entity = Entity.new()

	entity.id = entity_id
	entity.name = data.get("name", "Entity")

	# Add to world BEFORE applying component data (Pitfall 6)
	_ns._world.add_entity(entity)
	# Apply node transform from serialized position (e.g. projectile spawn point)
	var node_pos = data.get("node_position")
	if node_pos != null:
		entity.set("global_position", node_pos)
		var node_rot = data.get("node_rotation")
		if node_rot != null:
			entity.set("global_rotation", node_rot)
	_apply_component_data(entity, data)

	if _ns.get("_relationship_handler") != null:
		var rel_data = data.get("relationships", [])
		_ns._relationship_handler.apply_entity_relationships(entity, rel_data)

	_ns._spawn_counter += 1


## Handle an incoming despawn payload.
## Rejects silently if session_id != _ns._game_session_id.
## Graceful no-op if entity_id is unknown.
func handle_despawn_entity(entity_id: String, session_id: int = 0) -> void:
	# Reject stale despawns from previous game sessions
	if session_id != _ns._game_session_id:
		return

	var entity = _ns._world.entity_id_registry.get(entity_id)
	if entity:
		_ns._world.remove_entity(entity)
		if is_instance_valid(entity):
			entity.queue_free()
	# Graceful no-op if entity not found


# ============================================================================
# COMPONENT DATA APPLICATION
# ============================================================================


## Apply serialized component data to an entity.
func _apply_component_data(entity: Entity, data: Dictionary) -> void:
	var components_data = data.get("components", {})
	var script_paths = data.get("script_paths", {})

	_ns._applying_network_data = true
	for comp_type in components_data.keys():
		var comp_values = components_data[comp_type]
		# Find existing component by type name
		var existing_comp = _find_component_by_type(entity, comp_type)
		if existing_comp:
			# Update existing component properties
			for prop in comp_values.keys():
				if prop in existing_comp:
					existing_comp.set(prop, comp_values[prop])
		elif script_paths.has(comp_type):
			# Add missing component from script path
			var script_path = script_paths[comp_type]
			if not script_path.begins_with("res://"):
				push_warning("[SpawnManager] Invalid script path: %s" % script_path)
				continue
			if not ResourceLoader.exists(script_path):
				push_warning("[SpawnManager] Script not found: %s" % script_path)
				continue
			var script = load(script_path)
			if script:
				var new_comp = script.new()
				entity.add_component(new_comp)
				for prop in comp_values.keys():
					if prop in new_comp:
						new_comp.set(prop, comp_values[prop])
	_ns._applying_network_data = false

	# Inject authority markers after all component data is applied (LIFE-05)
	var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
	if net_id:
		_inject_authority_markers(entity, net_id)

	# Set up MultiplayerSynchronizer if entity has CN_NativeSync (SYNC-04)
	if _ns.get("_native_sync_handler") != null:
		_ns._native_sync_handler.setup_native_sync(entity)

	# Scan CN_NetSync after all components are set up so SyncSender can detect changes
	var net_sync: CN_NetSync = entity.get_component(CN_NetSync)
	if net_sync:
		net_sync.scan_entity_components(entity)


## Inject CN_LocalAuthority and CN_ServerAuthority markers onto entity.
## Called from _apply_component_data() after CN_NetworkIdentity is populated.
## Idempotent: removes existing markers before adding new ones (safe on re-spawn).
func _inject_authority_markers(entity: Entity, net_id: CN_NetworkIdentity) -> void:
	# Remove stale markers first -- idempotent re-spawn safety
	entity.remove_component(CN_LocalAuthority)
	entity.remove_component(CN_ServerAuthority)

	# CN_ServerAuthority: server-owned entities (peer_id == 0) on ALL peers
	if net_id.is_server_owned():
		entity.add_component(CN_ServerAuthority.new())

	# CN_LocalAuthority: local peer's own entity
	# Also: server gets CN_LocalAuthority on server-owned entities (server "is local" for them)
	if (
		net_id.is_local(_ns.net_adapter)
		or (_ns.net_adapter.is_server() and net_id.is_server_owned())
	):
		entity.add_component(CN_LocalAuthority.new())


## Find a component on an entity by its type name string.
func _find_component_by_type(entity: Entity, comp_type: String) -> Component:
	for comp in entity.components.values():
		var script = comp.get_script()
		var ct: String
		if script == null:
			ct = comp.get_class()
		else:
			ct = script.get_global_name()
			if ct == "":
				ct = script.resource_path.get_file().get_basename()
		if ct == comp_type:
			return comp
	return null


# ============================================================================
# ENTITY LIFECYCLE HOOKS (called by NetworkSync signal handlers)
# ============================================================================


## Handle a full world state snapshot sent to a late-joining peer.
## CRITICAL: syncs session_id FIRST so handle_spawn_entity() accepts the payloads.
func handle_world_state(state: Dictionary) -> void:
	var server_session_id = state.get("session_id", 0)
	if server_session_id != _ns._game_session_id:
		_ns._game_session_id = server_session_id
	for entity_data in state.get("entities", []):
		handle_spawn_entity(entity_data)


## Called when an entity is added to the world on the server.
## If the entity has CN_NetworkIdentity, queues a deferred broadcast spawn.
func on_entity_added(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	if not _ns.net_adapter.is_server():
		return
	if not entity.has_component(CN_NetworkIdentity):
		return

	# Queue entity for deferred broadcast (avoids broadcasting before components are fully set up)
	if not _ns._broadcast_pending.has(entity.id):
		_ns._broadcast_pending[entity.id] = entity
		# Defer the actual broadcast so all components are set up first.
		# _deferred_broadcast validates the entity is still valid and still pending.
		_ns.call_deferred("_deferred_broadcast", entity, entity.id)


## Called when an entity is removed from the world.
## If entity was pending broadcast (added then removed same frame), cancels the broadcast.
## Otherwise, broadcasts a despawn RPC to all clients.
func on_entity_removed(entity: Entity) -> void:
	if _ns._broadcast_pending.has(entity.id):
		# Cancel pending broadcast — entity removed before it could be sent
		_ns._broadcast_pending.erase(entity.id)
		# No despawn RPC needed — clients never received the spawn
	else:
		# Entity was already broadcast — send despawn to all clients
		_ns.rpc_broadcast_despawn(entity.id, _ns._game_session_id)


## Called when a peer disconnects from the session.
## Removes all entities owned by the disconnected peer.
func on_peer_disconnected(peer_id: int) -> void:
	if _ns._world == null:
		return
	var to_remove: Array = []
	for entity in _ns._world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if net_id and net_id.peer_id == peer_id:
			to_remove.append(entity)

	for entity in to_remove:
		_ns._world.remove_entity(entity)
		if is_instance_valid(entity):
			entity.queue_free()
