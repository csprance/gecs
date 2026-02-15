extends RefCounted
## Component property sync: change detection, queuing, batching, sending.
##
## Internal helper for NetworkSync. No class_name - not part of public API.

var _ns  # NetworkSync reference (untyped to avoid circular deps)


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# WORLD SIGNAL HANDLERS (component added/removed)
# ============================================================================


func on_component_added(entity: Entity, component: Resource) -> void:
	# Setup native sync when model_ready_component is added (model ready, sync target exists)
	if _ns.sync_config.model_ready_component != "":
		var script = component.get_script()
		if script:
			var comp_name = script.get_global_name()
			if comp_name == _ns.sync_config.model_ready_component:
				if entity.has_component(CN_SyncEntity):
					_ns._native_handler.auto_setup_native_sync(entity)
				return  # Don't queue model_ready_component for network sync

	# Skip marker components - they're managed locally
	if (
		component is CN_LocalAuthority
		or component is CN_RemoteEntity
		or component is CN_ServerOwned
		or component is CN_ServerAuthority
	):
		return

	# Skip if we're applying network data - prevents sync loops
	if _ns._applying_network_data:
		return

	# Queue full component sync when component is added
	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return

	# SPAWN-ONLY SYNC: Skip continuous sync for entities without CN_SyncEntity.
	# Their components are only synced at spawn time via _serialize_entity_spawn.
	if not entity.has_component(CN_SyncEntity):
		return

	# Skip if entity spawn hasn't been broadcast to clients yet.
	# The deferred _broadcast_entity_spawn will include all current components.
	if _ns._broadcast_pending.has(entity.id):
		return

	if should_broadcast(entity, net_id):
		queue_full_component_sync(entity, component)

		# Broadcast component addition to clients so they receive new components
		# (e.g., C_Dying on enemies triggers client-side death chain)
		var script = component.get_script()
		if script:
			var comp_type = script.get_global_name()
			if comp_type == "":
				comp_type = script.resource_path.get_file().get_basename()
			var script_path = script.resource_path
			var comp_data = component.serialize()
			if _ns.debug_logging:
				print("Broadcasting component addition: %s to %s" % [comp_type, entity.id])
			if _ns.net_adapter.is_server():
				_ns._add_component.rpc(
					entity.id, comp_type, script_path, comp_data, _ns._game_session_id
				)
			else:
				_ns._add_component.rpc_id(
					1, entity.id, comp_type, script_path, comp_data, _ns._game_session_id
				)


func on_component_removed(entity: Entity, component: Resource) -> void:
	# Skip marker components - they're managed locally
	if (
		component is CN_LocalAuthority
		or component is CN_RemoteEntity
		or component is CN_ServerOwned
		or component is CN_ServerAuthority
	):
		return

	# Skip if we're applying network data - prevents sync loops
	if _ns._applying_network_data:
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# Only broadcast if we have authority
	if not should_broadcast(entity, net_id):
		return

	# Get component type name
	var script = component.get_script()
	if script == null:
		return
	var comp_type = script.get_global_name()
	if comp_type == "":
		comp_type = script.resource_path.get_file().get_basename()

	if _ns.debug_logging:
		print("Broadcasting component removal: %s from %s" % [comp_type, entity.id])

	# Broadcast removal
	if _ns.net_adapter.is_server():
		_ns._remove_component.rpc(entity.id, comp_type)
	else:
		_ns._remove_component.rpc_id(1, entity.id, comp_type)


# ============================================================================
# PROPERTY CHANGE HANDLER
# ============================================================================


func on_component_property_changed(
	entity: Entity, component: Resource, property: String, _old_value, new_value
) -> void:
	# Skip if we're applying network data - prevents sync loops
	if _ns._applying_network_data:
		return

	# Check if this component should be skipped (C_Transform handled by native sync)
	if _ns.sync_config and _ns.sync_config.should_skip_component(component):
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# SECURITY: Prevent clients from syncing CN_NetworkIdentity even if it becomes a SyncComponent
	# This ensures ownership can never be transferred by a client
	if component is CN_NetworkIdentity and not _ns.net_adapter.is_server():
		return

	# SPAWN-ONLY SYNC: Entities without CN_SyncEntity only sync at spawn time.
	# Skip continuous property sync for these entities (e.g., projectiles).
	# This allows local deterministic simulation without network interference.
	if not entity.has_component(CN_SyncEntity):
		return

	if should_broadcast(entity, net_id):
		queue_component_update(entity, component, property, new_value)

		# Log HIGH priority component changes for debugging sync flow
		if _ns.debug_logging:
			var script = component.get_script()
			var comp_type = script.get_global_name() if script else component.get_class()
			var priority = (
				_ns.sync_config.get_priority(component)
				if _ns.sync_config
				else SyncConfig.Priority.MEDIUM
			)
			if priority == SyncConfig.Priority.HIGH:
				var prefix = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"
				print(
					(
						"%s: Property change queued: entity=%s, comp=%s, prop=%s"
						% [prefix, entity.id, comp_type, property]
					)
				)


func should_broadcast(_entity: Entity, net_id: CN_NetworkIdentity) -> bool:
	# Server broadcasts ALL changes
	if _ns.net_adapter.is_server():
		return true

	# Client only broadcasts for entities they own (local player)
	return net_id.peer_id == _ns.net_adapter.get_my_peer_id()


# ============================================================================
# UPDATE QUEUING
# ============================================================================


func queue_component_update(
	entity: Entity, component: Resource, property: String, value: Variant
) -> void:
	var entity_id = entity.id
	var script = component.get_script()
	var comp_type: String
	if script == null:
		comp_type = component.get_class()
	else:
		comp_type = script.get_global_name()
		if comp_type == "":
			comp_type = script.resource_path.get_file().get_basename()

	# Get priority for this component type
	var priority = (
		_ns.sync_config.get_priority(component) if _ns.sync_config else SyncConfig.Priority.MEDIUM
	)

	# Ensure priority batch exists
	if not _ns._pending_updates_by_priority.has(priority):
		_ns._pending_updates_by_priority[priority] = {}
	if not _ns._pending_updates_by_priority[priority].has(entity_id):
		_ns._pending_updates_by_priority[priority][entity_id] = {}
	if not _ns._pending_updates_by_priority[priority][entity_id].has(comp_type):
		_ns._pending_updates_by_priority[priority][entity_id][comp_type] = {}

	# For transform component, always send both position and rotation together
	# This ensures rotation-only updates don't get filtered out on the receiving end
	if (
		_ns.sync_config.transform_component != ""
		and comp_type == _ns.sync_config.transform_component
	):
		# Use generic property access since component class name is configurable
		if "position" in component and "rotation" in component:
			_ns._pending_updates_by_priority[priority][entity_id][comp_type]["position"] = (
				component.get("position")
			)
			_ns._pending_updates_by_priority[priority][entity_id][comp_type]["rotation"] = (
				component.get("rotation")
			)
		else:
			# Fallback if properties don't exist
			_ns._pending_updates_by_priority[priority][entity_id][comp_type][property] = value
	else:
		_ns._pending_updates_by_priority[priority][entity_id][comp_type][property] = value


func queue_full_component_sync(entity: Entity, component: Resource) -> void:
	var entity_id = entity.id
	var script = component.get_script()
	var comp_type: String
	if script == null:
		comp_type = component.get_class()
	else:
		comp_type = script.get_global_name()
		if comp_type == "":
			comp_type = script.resource_path.get_file().get_basename()
	var data = component.serialize()

	# Get priority for this component type
	var priority = (
		_ns.sync_config.get_priority(component) if _ns.sync_config else SyncConfig.Priority.MEDIUM
	)

	if not _ns._pending_updates_by_priority.has(priority):
		_ns._pending_updates_by_priority[priority] = {}
	if not _ns._pending_updates_by_priority[priority].has(entity_id):
		_ns._pending_updates_by_priority[priority][entity_id] = {}

	_ns._pending_updates_by_priority[priority][entity_id][comp_type] = data


## Queue received client data for relay to other clients (server only)
## This ensures rotation-only updates get relayed when player is stationary
func queue_relay_data(entity_id: String, comp_data: Dictionary) -> void:
	# Relay data uses HIGH priority for responsiveness
	var priority = SyncConfig.Priority.HIGH

	if not _ns._pending_updates_by_priority.has(priority):
		_ns._pending_updates_by_priority[priority] = {}
	if not _ns._pending_updates_by_priority[priority].has(entity_id):
		_ns._pending_updates_by_priority[priority][entity_id] = {}

	# Merge received component data into pending updates
	for comp_type in comp_data.keys():
		if not _ns._pending_updates_by_priority[priority][entity_id].has(comp_type):
			_ns._pending_updates_by_priority[priority][entity_id][comp_type] = {}

		# Merge properties (received data takes priority for relay)
		for prop_name in comp_data[comp_type].keys():
			_ns._pending_updates_by_priority[priority][entity_id][comp_type][prop_name] = (comp_data[comp_type][prop_name])


# ============================================================================
# SYNC TIMERS & SENDING
# ============================================================================


func update_sync_timers(delta: float) -> void:
	for priority in _ns._sync_timers.keys():
		_ns._sync_timers[priority] += delta


func send_pending_updates_batched() -> void:
	# Send updates for each priority level when its interval has elapsed
	for priority in SyncConfig.Priority.values():
		if not SyncConfig.should_sync(priority, _ns._sync_timers[priority]):
			continue

		# Reset timer for this priority
		_ns._sync_timers[priority] = 0.0

		# Poll SyncComponents for changes at this priority level
		poll_sync_components_for_priority(priority)

		# Get pending updates for this priority
		if not _ns._pending_updates_by_priority.has(priority):
			continue
		var batch = _ns._pending_updates_by_priority[priority]
		if batch.is_empty():
			continue

		# Clear the batch before sending (prevents double-send)
		_ns._pending_updates_by_priority[priority] = {}

		# Log batch send details for debugging sync flow
		if _ns.debug_logging:
			var entity_count = batch.size()
			var prop_count = 0
			for entity_id in batch.keys():
				for comp_type in batch[entity_id].keys():
					prop_count += batch[entity_id][comp_type].size()
			var priority_name = SyncConfig.Priority.keys()[priority]
			var prefix = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"
			print(
				(
					"%s: Batch send: priority=%s, entities=%d, properties=%d"
					% [prefix, priority_name, entity_count, prop_count]
				)
			)

		# Choose RPC method based on reliability
		var reliability = SyncConfig.get_reliability(priority)

		# Server sends to all clients
		if _ns.net_adapter.is_server():
			if reliability == SyncConfig.Reliability.UNRELIABLE:
				_ns._sync_components_unreliable.rpc(batch)
			else:
				_ns._sync_components_reliable.rpc(batch)
		else:
			# Client sends to server only (for owned entities)
			if reliability == SyncConfig.Reliability.UNRELIABLE:
				_ns._sync_components_unreliable.rpc_id(1, batch)
			else:
				_ns._sync_components_reliable.rpc_id(1, batch)


## Poll all SyncComponents for changes at a specific priority level.
## This triggers property_changed signals for any detected changes,
## which then get queued via on_component_property_changed().
##
## Uses _sync_entity_index (maintained by NetworkSync) to avoid iterating
## all world entities and all their components every tick. Only entities
## with CN_NetworkIdentity + at least one SyncComponent are in the index.
func poll_sync_components_for_priority(priority: int) -> void:
	for entry in _ns._sync_entity_index.values():
		var entity: Entity = entry["entity"]
		if not is_instance_valid(entity):
			continue

		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue

		# Only broadcast changes for entities we have authority over
		if not should_broadcast(entity, net_id):
			continue

		# Poll cached SyncComponents directly (no inner component scan)
		for comp in entry["sync_comps"]:
			if is_instance_valid(comp):
				comp.check_changes_for_priority(priority)


# ============================================================================
# APPLY SYNC DATA (from RPC)
# ============================================================================


## Shared handler for both reliable and unreliable syncs
func handle_apply_sync_data(data: Dictionary) -> void:
	var sender_id = _ns.net_adapter.get_remote_sender_id()
	var prefix = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"

	# Log incoming sync data at DEBUG level
	if _ns.debug_logging:
		var entity_count = data.size()
		var total_props = 0
		var comp_types: Array[String] = []
		for entity_id in data.keys():
			for comp_type in data[entity_id].keys():
				if comp_type not in comp_types:
					comp_types.append(comp_type)
				total_props += data[entity_id][comp_type].size()
		print(
			(
				"%s: Received sync data from peer %d: entities=%d, components=%s, properties=%d"
				% [prefix, sender_id, entity_count, comp_types, total_props]
			)
		)

	for entity_id in data.keys():
		var entity = _ns._world.entity_id_registry.get(entity_id)
		if not entity:
			if _ns.debug_logging:
				print("Received update for unknown entity: %s" % entity_id)
			continue

		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue

		# SPAWN-ONLY SYNC: Skip continuous updates for entities without CN_SyncEntity.
		# These entities (e.g., projectiles) only sync at spawn time.
		if not entity.has_component(CN_SyncEntity):
			if _ns.debug_logging:
				print("Skipping sync data for spawn-only entity: %s" % entity_id)
			continue

		# Validation: Only accept updates from authorized sources
		if _ns.net_adapter.is_server():
			# Server accepts updates from entity owner only
			if net_id.peer_id != sender_id:
				if _ns.debug_logging:
					print(
						(
							"Rejected update from peer %d for entity owned by peer %d"
							% [sender_id, net_id.peer_id]
						)
					)
				continue

			# SECURITY: Prevent clients from updating CN_NetworkIdentity (ownership transfer)
			# Even if a client modifies their local component and sends it, the server must reject it.
			if data[entity_id].has("CN_NetworkIdentity"):
				if _ns.debug_logging:
					print("SECURITY: Rejected CN_NetworkIdentity update from client %d" % sender_id)
				data[entity_id].erase("CN_NetworkIdentity")
				if data[entity_id].is_empty():
					continue

			# SERVER RELAY: Queue received client data for broadcast to all clients
			# This ensures rotation-only updates (when stationary) get relayed
			# The sending client filters out their own entity in the receive path
			queue_relay_data(entity_id, data[entity_id])
		else:
			# Clients accept updates from server (peer 1) only
			if sender_id != 1:
				if _ns.debug_logging:
					print("Rejected update from non-server peer %d" % sender_id)
				continue

			# Skip updates for entities we own (prevents stale relayed data from
			# overwriting local predictions). Note: server-authoritative changes for
			# locally-owned entities (e.g. health) are typically at MEDIUM priority
			# and arrive in a separate batch from HIGH-priority relay data.
			if net_id.is_local(_ns.net_adapter):
				continue

			# Server is authoritative for all game state (health, damage, etc.)
			# Client sends INPUT to server, server sends RESULTS back to ALL clients

		# Apply component data
		_ns._apply_component_data(entity, data[entity_id])

		# Log applied component data at DEBUG level
		if _ns.debug_logging:
			var applied_comps: Array[String] = []
			for comp_type in data[entity_id].keys():
				applied_comps.append(comp_type)
			print(
				(
					"%s: Applied sync data to entity=%s: components=%s"
					% [prefix, entity_id, applied_comps]
				)
			)
