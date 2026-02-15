extends RefCounted
## State management: authority markers, reconciliation, time sync, diagnostics.
##
## Internal helper for NetworkSync. No class_name - not part of public API.

var _ns  # NetworkSync reference (untyped to avoid circular deps)


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# AUTO-MARKER ASSIGNMENT
# ============================================================================


func auto_assign_markers(entity: Entity) -> void:
	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# Remove existing marker components to prevent duplicates
	if entity.has_component(CN_LocalAuthority):
		entity.remove_component(entity.get_component(CN_LocalAuthority))
	if entity.has_component(CN_RemoteEntity):
		entity.remove_component(entity.get_component(CN_RemoteEntity))
	if entity.has_component(CN_ServerOwned):
		entity.remove_component(entity.get_component(CN_ServerOwned))
	if entity.has_component(CN_ServerAuthority):
		entity.remove_component(entity.get_component(CN_ServerAuthority))

	# Assign markers based on ownership
	# Server has local authority over:
	#   - Server-owned entities (peer_id=0): enemies, projectiles, pickups
	#   - Host player entity (peer_id=1)
	# Clients have local authority only over their own player entity
	var is_entity_local = false
	var my_peer_id = _ns.net_adapter.get_my_peer_id()
	var is_server = _ns.net_adapter.is_server()

	# DEBUG: Log marker assignment details
	if _ns.debug_logging:
		print(
			(
				"[auto_assign_markers] Entity: %s, net_id.peer_id=%d, my_peer_id=%d, is_server=%s"
				% [entity.name, net_id.peer_id, my_peer_id, is_server]
			)
		)

	if is_server:
		# Server has authority over server-owned (0) and host player (1)
		is_entity_local = net_id.peer_id == 0 or net_id.peer_id == my_peer_id
	else:
		# Client has authority only over their own player
		is_entity_local = net_id.peer_id == my_peer_id

	if is_entity_local:
		entity.add_component(CN_LocalAuthority.new())
		if _ns.debug_logging:
			print(
				"Added CN_LocalAuthority to entity: %s (peer_id=%d)" % [entity.id, net_id.peer_id]
			)
	else:
		entity.add_component(CN_RemoteEntity.new())
		if _ns.debug_logging:
			print("Added CN_RemoteEntity to entity: %s (peer_id=%d)" % [entity.id, net_id.peer_id])

	if net_id.is_server_owned():
		entity.add_component(CN_ServerOwned.new())
		# Add CN_ServerAuthority to server-owned entities (enemies, projectiles, pickups)
		# This enables query-based filtering: q.with_all([CN_ServerAuthority, CN_LocalAuthority])
		# Server has CN_LocalAuthority on server-owned entities, clients don't
		entity.add_component(CN_ServerAuthority.new())
		if _ns.debug_logging:
			print("Added CN_ServerOwned + CN_ServerAuthority to entity: %s" % entity.id)


# ============================================================================
# AUTHORITY TRANSFER
# ============================================================================


func transfer_authority(entity: Entity, new_owner_peer_id: int) -> void:
	if not _ns.net_adapter.is_server():
		print("Only server can transfer authority")
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		print("Cannot transfer authority: entity has no CN_NetworkIdentity")
		return

	if not _is_valid_peer(new_owner_peer_id):
		print("Invalid peer ID for authority transfer: %d" % new_owner_peer_id)
		return

	var old_owner = net_id.peer_id

	# Update peer_id
	net_id.peer_id = new_owner_peer_id

	# Reassign markers
	auto_assign_markers(entity)

	# Update MultiplayerSynchronizer authority if present
	var sync_comp = entity.get_component(CN_SyncEntity)
	if sync_comp:
		var target = sync_comp.get_sync_target(entity)
		if target:
			var synchronizer = target.get_node_or_null("_NetSync")
			if synchronizer:
				synchronizer.set_multiplayer_authority(
					new_owner_peer_id if new_owner_peer_id > 0 else 1
				)

	# Broadcast authority change to all clients
	_ns._broadcast_authority_change.rpc(entity.id, new_owner_peer_id)

	if _ns.debug_logging:
		print(
			(
				"Transferred authority of %s from peer %d to peer %d"
				% [entity.id, old_owner, new_owner_peer_id]
			)
		)


func handle_broadcast_authority_change(entity_id: String, new_owner_peer_id: int) -> void:
	var entity = _ns._world.entity_id_registry.get(entity_id)
	if not entity:
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if net_id:
		net_id.peer_id = new_owner_peer_id
		auto_assign_markers(entity)

		# Update synchronizer authority
		var sync_comp = entity.get_component(CN_SyncEntity)
		if sync_comp:
			var target = sync_comp.get_sync_target(entity)
			if target:
				var synchronizer = target.get_node_or_null("_NetSync")
				if synchronizer:
					synchronizer.set_multiplayer_authority(
						new_owner_peer_id if new_owner_peer_id > 0 else 1
					)


func _is_valid_peer(peer_id: int) -> bool:
	if peer_id == 0:
		return true  # Server-owned
	if peer_id == 1:
		return true  # Host

	# Check if peer is connected
	var peers = _ns.net_adapter.get_connected_peers()
	return peer_id in peers or peer_id == _ns.net_adapter.get_my_peer_id()


# ============================================================================
# RECONCILIATION (Periodic Full State Sync)
# ============================================================================


## Process reconciliation timer (server only)
func process_reconciliation(delta: float) -> void:
	if not _ns.net_adapter.is_server():
		return

	if not _ns.sync_config or not _ns.sync_config.enable_reconciliation:
		return

	_ns._reconciliation_timer += delta

	if _ns._reconciliation_timer >= _ns.sync_config.reconciliation_interval:
		_ns._reconciliation_timer = 0.0
		broadcast_full_state()


## Broadcast full state of all networked entities to all clients
func broadcast_full_state() -> void:
	if not _ns.net_adapter.is_server():
		return

	var full_state: Dictionary = {}

	for entity in _ns._world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue

		full_state[entity.id] = serialize_entity_full(entity)

	if full_state.is_empty():
		return

	if _ns.debug_logging:
		print("Broadcasting full state reconciliation (%d entities)" % full_state.size())

	_ns._sync_full_state.rpc(full_state)


## Serialize all component data for an entity (includes script_paths for missing component creation)
func serialize_entity_full(entity: Entity) -> Dictionary:
	var components_data: Dictionary = {}
	var script_paths: Dictionary = {}

	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		var script = comp.get_script()
		if script == null:
			continue
		var comp_type = script.get_global_name()
		if comp_type == "":
			comp_type = script.resource_path.get_file().get_basename()

		# Skip components that should be filtered
		if _ns.sync_config and _ns.sync_config.should_skip(comp_type):
			continue

		components_data[comp_type] = comp.serialize()
		script_paths[comp_type] = script.resource_path

	var result = {"components": components_data, "script_paths": script_paths}

	# Include relationships if sync is enabled
	var relationships = _ns._relationship_handler.serialize_entity_relationships(entity)
	if not relationships.is_empty():
		result["relationships"] = relationships

	return result


## Receive full state reconciliation from server
func handle_sync_full_state(state: Dictionary) -> void:
	if _ns.debug_logging:
		print("Received full state reconciliation (%d entities)" % state.size())

	for entity_id in state.keys():
		var entity = _ns._world.entity_id_registry.get(entity_id)
		if not entity:
			if _ns.debug_logging:
				print("Reconciliation: unknown entity %s" % entity_id)
			continue

		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue

		# Skip local entities - we're authoritative for our own data
		if net_id.is_local(_ns.net_adapter):
			continue

		var entity_data = state[entity_id]
		# Support both old format (flat) and new format (nested with script_paths)
		var comp_data = entity_data.get("components", entity_data)
		var script_paths = entity_data.get("script_paths", {})

		# Apply full state with force_overwrite to correct any drift
		_ns._apply_component_data(entity, comp_data, true)

		# Create missing components from reconciliation data
		for comp_type in comp_data.keys():
			if _ns._find_component_by_type(entity, comp_type):
				continue
			if not script_paths.has(comp_type):
				continue

			# Validate script path before loading
			var script_path = script_paths[comp_type]
			if not script_path.begins_with("res://"):
				push_warning(
					(
						"[RECONCILIATION] Invalid script path for %s: %s (must start with res://)"
						% [comp_type, script_path]
					)
				)
				continue

			if not ResourceLoader.exists(script_path):
				push_warning(
					"[RECONCILIATION] Script not found for %s: %s" % [comp_type, script_path]
				)
				continue

			var script = load(script_path)
			if not script:
				push_warning(
					"[RECONCILIATION] Failed to load script for %s: %s" % [comp_type, script_path]
				)
				continue

			var new_comp = script.new()
			_ns._applying_network_data = true
			entity.add_component(new_comp)
			_ns._applying_network_data = false
			_ns._apply_component_data(entity, {comp_type: comp_data[comp_type]})
			if _ns.debug_logging:
				print("[RECONCILIATION] Added missing component %s to %s" % [comp_type, entity_id])

		# Reconcile relationships: replace with server state
		var rel_data = entity_data.get("relationships", [])
		if not rel_data.is_empty():
			_ns._applying_network_data = true
			entity.remove_all_relationships()
			_ns._applying_network_data = false
			_ns._relationship_handler.apply_entity_relationships(entity, rel_data)

	# Ghost cleanup: Remove local entities that don't exist on the server
	# This catches entities where both the despawn RPC and component sync failed
	var ghosts_removed := 0
	for entity in _ns._world.entities.duplicate():
		if not is_instance_valid(entity):
			continue
		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue
		# Skip locally-owned entities - we're authoritative for those
		if net_id.is_local(_ns.net_adapter):
			continue
		# If server's full state doesn't include this entity, it's a ghost
		if not state.has(entity.id):
			print(
				(
					"[RECONCILIATION] Removing ghost entity: %s (name=%s, not in server state)"
					% [entity.id, entity.name]
				)
			)
			_ns._world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.queue_free()
			ghosts_removed += 1

	if ghosts_removed > 0:
		print("[RECONCILIATION] Removed %d ghost entities" % ghosts_removed)


# ============================================================================
# SERVER TIME SYNCHRONIZATION
# ============================================================================


## Sync client's clock with server time (clients only)
func sync_server_time(delta: float) -> void:
	if _ns.net_adapter.is_server():
		return  # Server is the time authority

	_ns._ping_timer += delta

	# Initial sync or periodic re-sync
	if not _ns._time_sync_initialized or _ns._ping_timer >= _ns._ping_interval:
		_ns._ping_timer = 0.0
		send_time_ping()


func send_time_ping() -> void:
	_ns._ping_counter += 1
	var ping_id = _ns._ping_counter
	var send_time = Time.get_ticks_msec() / 1000.0

	# Purge stale pings (no response within 3 ping intervals)
	var stale_threshold = send_time - _ns._ping_interval * 3.0
	var stale_ids: Array = []
	for id in _ns._pending_pings:
		if _ns._pending_pings[id] < stale_threshold:
			stale_ids.append(id)
	for id in stale_ids:
		_ns._pending_pings.erase(id)

	_ns._pending_pings[ping_id] = send_time
	_ns._request_server_time.rpc_id(1, ping_id)

	if _ns.debug_logging:
		print("Sent time ping %d" % ping_id)


func handle_request_server_time(ping_id: int) -> void:
	if not _ns.net_adapter.is_server():
		return
	var server_time = Time.get_ticks_msec() / 1000.0
	_ns._respond_server_time.rpc_id(_ns.net_adapter.get_remote_sender_id(), ping_id, server_time)


func handle_respond_server_time(ping_id: int, server_time: float) -> void:
	if not _ns._pending_pings.has(ping_id):
		return

	var send_time = _ns._pending_pings[ping_id]
	_ns._pending_pings.erase(ping_id)

	var receive_time = Time.get_ticks_msec() / 1000.0
	var rtt = receive_time - send_time

	# Estimate server time at receive moment (server_time + half RTT)
	var estimated_server_now = server_time + (rtt / 2.0)
	_ns._server_time_offset = estimated_server_now - receive_time

	_ns._time_sync_initialized = true

	if _ns.debug_logging:
		print("Time sync: offset=%.3fs, RTT=%.1fms" % [_ns._server_time_offset, rtt * 1000])


# ============================================================================
# DIAGNOSTICS
# ============================================================================


## Callback when MultiplayerSynchronizer syncs (for diagnostics)
func on_synchronizer_synchronized(entity_name: String) -> void:
	# This is called frequently - only log occasionally
	if Engine.get_process_frames() % 120 == 0:  # Every ~2 seconds at 60fps
		print("[NetworkSync] Synchronizer synced for: %s" % entity_name)


## Process entity count diagnostics to track desync between peers
func process_entity_count_diagnostics(delta: float) -> void:
	_ns._entity_count_timer += delta
	if _ns._entity_count_timer < _ns.ENTITY_COUNT_INTERVAL:
		return

	_ns._entity_count_timer = 0.0

	# Count networked entities by type
	var category_counts: Dictionary = {}
	var enemy_names: Array[String] = []

	for entity in _ns._world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue

		# Get entity category from SyncConfig (or fallback to peer_id heuristic)
		var category = "other"
		if _ns.sync_config:
			category = _ns.sync_config.get_entity_category(entity)
		else:
			# Fallback to peer_id heuristic if no config
			if net_id.peer_id > 0:
				category = "player"

		# Increment category count
		if not category_counts.has(category):
			category_counts[category] = 0
		category_counts[category] += 1

		# Collect enemy names for detailed logging
		if category == "enemy":
			enemy_names.append(entity.name)

	# Sort enemy names for comparison
	enemy_names.sort()

	# Extract common counts for backward-compatible logging
	var enemy_count = category_counts.get("enemy", 0)
	var player_count = category_counts.get("player", 0)
	var other_count = category_counts.get("other", 0)

	var prefix = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"
	var peer_id = _ns.net_adapter.get_my_peer_id()
	print(
		(
			"[ENTITY-COUNT] %s (peer %d): enemies=%d, players=%d, other=%d, session=%d"
			% [prefix, peer_id, enemy_count, player_count, other_count, _ns._game_session_id]
		)
	)
	print("[ENTITY-COUNT] %s enemies: %s" % [prefix, enemy_names])


## Process diagnostic logging for native sync (to verify it's working)
func process_sync_diagnostics(delta: float) -> void:
	if not _ns.debug_logging:
		return

	_ns._sync_diagnostic_timer += delta
	if _ns._sync_diagnostic_timer < _ns.SYNC_DIAGNOSTIC_INTERVAL:
		return

	_ns._sync_diagnostic_timer = 0.0

	# Count entities with active MultiplayerSynchronizers
	var sync_count = 0
	var missing_sync_count = 0
	var sample_positions: Array[String] = []

	for entity in _ns._world.entities:
		var sync_comp = entity.get_component(CN_SyncEntity)
		if not sync_comp:
			continue

		var target = sync_comp.get_sync_target(entity)
		if not target:
			continue

		var synchronizer = target.get_node_or_null("_NetSync") as MultiplayerSynchronizer
		if synchronizer:
			sync_count += 1
			# Sample first few positions for diagnostic output
			if sample_positions.size() < 3 and "global_position" in target:
				var pos: Vector3 = target.global_position
				sample_positions.append("%s@(%.1f,%.1f,%.1f)" % [entity.name, pos.x, pos.y, pos.z])
		else:
			missing_sync_count += 1

	var prefix = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"
	print(
		(
			"[NetworkSync] %s: Native sync status - %d active, %d missing, samples: %s"
			% [prefix, sync_count, missing_sync_count, sample_positions]
		)
	)


# ============================================================================
# ENTITY ID GENERATION
# ============================================================================


## Generate a unique network ID for an entity.
## @param peer_id: The peer ID of the owner
## @param use_deterministic: If true, use counter-based ID (for debugging)
## @return: A unique entity ID string
## @note Requires GECS addon (addons/gecs/io/io.gd) for GECSIO.uuid()
func generate_network_id(peer_id: int, use_deterministic: bool = false) -> String:
	if use_deterministic:
		_ns._spawn_counter += 1
		var timestamp = Time.get_ticks_msec()
		return "%d_%d_%d" % [peer_id, timestamp, _ns._spawn_counter]

	# Requires GECS addon: addons/gecs/io/io.gd
	return GECSIO.uuid()
