class_name SyncReceiver
extends RefCounted
## SyncReceiver — authority-validated, sync-loop-guarded component property applicator.
##
## Delegates from NetworkSync. Validates sender authority before applying any
## received property data, then calls CN_NetSync.update_cache_silent() to
## prevent echo detection of remotely-applied values.
##
## Server path authority rules:
##   1. Entity must exist in world
##   2. Entity must have CN_NetworkIdentity
##   3. Entity must have CN_NetSync (spawn-only entities are rejected, SYNC-03)
##   4. net_id.peer_id must match sender_id (ownership check)
##   5. CN_NetworkIdentity key stripped from comp_data (spoof prevention)
##   6. Relay queued via _ns._sender.queue_relay_data()
##   7. Component data applied
##
## Client path authority rules:
##   1. sender_id must be 1 (from server only)
##   2-4. Same existence/identity checks as server
##   5. Skip if net_id.peer_id == my_peer_id (own entity)
##   6. Component data applied

var _ns  # NetworkSync reference (untyped to avoid circular deps)

## Custom receive handlers: { "CompTypeName": Callable }
## Callable signature: func(entity: Entity, comp: Component, props: Dictionary) -> bool
## Return true if handled (framework still calls update_cache_silent), false to use default.
var _custom_receive_handlers: Dictionary = {}


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# PUBLIC API
# ============================================================================


## Register a custom receive handler for a component type.
## The handler is called instead of the default comp.set() for the named component type.
## The framework ALWAYS calls update_cache_silent() after the handler (prevents echo loops).
## Callable signature: func(entity: Entity, comp: Component, props: Dictionary) -> bool
## Return true if handled (skip default set()), false to fall through to default.
func register_receive_handler(comp_type_name: String, handler: Callable) -> void:
	_custom_receive_handlers[comp_type_name] = handler


## Entry point called by NetworkSync's @rpc handlers.
## batch format: { entity_id: { comp_type: { prop: value } } }
func handle_apply_sync_data(batch: Dictionary) -> void:
	var sender_id: int = _ns.net_adapter.get_remote_sender_id()

	if _ns.net_adapter.is_server():
		_handle_server_path(batch, sender_id)
	else:
		_handle_client_path(batch, sender_id)


# ============================================================================
# PRIVATE — SERVER PATH
# ============================================================================


func _handle_server_path(batch: Dictionary, sender_id: int) -> void:
	for entity_id in batch.keys():
		# 1. Entity must exist in world
		var entity: Entity = _ns._world.entity_id_registry.get(entity_id)
		if entity == null:
			continue

		# 2. Entity must have CN_NetworkIdentity
		var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
		if net_id == null:
			continue

		# 3. Entity must have CN_NetSync (spawn-only entities have no continuous updates)
		var net_sync: CN_NetSync = entity.get_component(CN_NetSync)
		if net_sync == null:
			continue

		# 4. Ownership check: only the entity owner may send updates
		if net_id.peer_id != sender_id:
			continue

		# 5. Strip CN_NetworkIdentity key (ownership spoof prevention)
		var comp_data: Dictionary = batch[entity_id].duplicate()
		if comp_data.has("CN_NetworkIdentity"):
			comp_data.erase("CN_NetworkIdentity")
			if comp_data.is_empty():
				continue  # Nothing left after stripping spoofed key

		# 6. Queue relay to broadcast validated data to all other clients
		if _ns.get("_sender") != null:
			_ns._sender.queue_relay_data(entity_id, comp_data)

		# 7. Apply component data
		_apply_component_data(entity, comp_data)


# ============================================================================
# PRIVATE — CLIENT PATH
# ============================================================================


func _handle_client_path(batch: Dictionary, sender_id: int) -> void:
	# 1. Reject entire batch if not from server (peer 1)
	if sender_id != 1:
		return

	for entity_id in batch.keys():
		# 2. Entity must exist in world
		var entity: Entity = _ns._world.entity_id_registry.get(entity_id)
		if entity == null:
			continue

		# 3a. Entity must have CN_NetworkIdentity
		var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
		if net_id == null:
			continue

		# 3b. Entity must have CN_NetSync (spawn-only rejection, SYNC-03)
		var net_sync: CN_NetSync = entity.get_component(CN_NetSync)
		if net_sync == null:
			continue

		# 5. Skip own entity (client is authoritative for its own entity position)
		if net_id.peer_id == _ns.net_adapter.get_my_peer_id():
			continue

		# 6. Apply component data
		_apply_component_data(entity, batch[entity_id])


# ============================================================================
# PRIVATE — COMPONENT DATA APPLICATION
# ============================================================================


## Apply a { comp_type: { prop: value } } dict to an entity.
## Guards with _applying_network_data = true to prevent echo sync loops.
## Calls update_cache_silent() after each set() to suppress re-detection.
## If a custom receive handler is registered for a comp_type, it is called first.
## When a handler returns true: update_cache_silent() is always called (echo prevention),
## then the default comp.set() path is skipped.
## When a handler returns false: falls through to the default comp.set() path.
func _apply_component_data(entity: Entity, comp_data: Dictionary) -> void:
	var net_sync: CN_NetSync = entity.get_component(CN_NetSync)

	_ns._applying_network_data = true
	for comp_type in comp_data.keys():
		var comp = _find_component_by_type(entity, comp_type)
		if comp == null:
			continue
		var props: Dictionary = comp_data[comp_type]
		if _custom_receive_handlers.has(comp_type):
			var handled: bool = _custom_receive_handlers[comp_type].call(entity, comp, props)
			# Always call update_cache_silent regardless of handler result — prevents echo loop
			if net_sync:
				for prop in props.keys():
					var value = props[prop]
					net_sync.update_cache_silent(comp, prop, value)
			if handled:
				continue  # Skip default comp.set() path
		# Default path (or fallthrough when handler returns false)
		for prop in props.keys():
			var value = props[prop]
			if prop in comp:
				comp.set(prop, value)
				# Silence the dirty cache so SyncSender won't re-detect this change
				if net_sync:
					net_sync.update_cache_silent(comp, prop, value)
	_ns._applying_network_data = false
	# Note: GDScript has no try/finally. _applying_network_data = false runs
	# unconditionally because Component.set() does not throw exceptions.


## Find a component on an entity by its type name string.
## Mirrors SpawnManager._find_component_by_type() exactly.
func _find_component_by_type(entity: Entity, comp_type: String) -> Component:
	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
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
