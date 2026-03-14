class_name SyncSender
extends RefCounted
## SyncSender — timer-accumulator driven, priority-tiered batch RPC dispatcher.
##
## Delegates from NetworkSync. Iterates world entities each tick, detects
## property changes via CN_NetSync, and dispatches batched RPCs at the correct
## frequency for each priority tier.
##
## Priority Hz (default, overridden by ProjectSettings):
##   REALTIME: every frame (0.0 interval)
##   HIGH:     20 Hz  (0.05 s)
##   MEDIUM:   10 Hz  (0.10 s)
##   LOW:       2 Hz  (0.50 s)

var _ns  # NetworkSync reference (untyped to avoid circular deps)

## Timer accumulators (seconds since last dispatch) per priority.
var _timers: Dictionary = {
	CN_NetSync.Priority.REALTIME: 0.0,
	CN_NetSync.Priority.HIGH: 0.0,
	CN_NetSync.Priority.MEDIUM: 0.0,
	CN_NetSync.Priority.LOW: 0.0,
}

## Pending update accumulator per priority: { entity_id: { comp_type: { prop: value } } }
var _pending: Dictionary = {
	CN_NetSync.Priority.REALTIME: {},
	CN_NetSync.Priority.HIGH: {},
	CN_NetSync.Priority.MEDIUM: {},
	CN_NetSync.Priority.LOW: {},
}

## Custom send handlers: { "CompTypeName": Callable }
## Callable signature: func(entity: Entity, comp: Component, priority: int) -> Dictionary
## Return {} to suppress, null to use default dirty-check.
var _custom_send_handlers: Dictionary = {}


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# PUBLIC API
# ============================================================================


## Main update entry. Call once per frame from NetworkSync._process().
## Skips when _applying_network_data (prevents echo) or not in game.
func tick(delta: float) -> void:
	# Guard: avoid echo-sending data we just received from the network
	if _ns._applying_network_data:
		return
	# Guard: only send when in an active game session
	if not _ns.net_adapter.is_in_game():
		return

	# Accumulate time for interval-based priorities
	for priority in _timers.keys():
		_timers[priority] += delta

	_flush_due_priorities()

	# TODO: consider entity index cache if profiling shows O(N) iteration
	# is bottleneck at 100+ entities


## Register a custom send handler for a component type.
## The handler is called instead of the default dirty-check for the named component type.
## Callable signature: func(entity: Entity, comp: Component, priority: int) -> Dictionary
## Return {} to suppress this component from outbound batch, null to use default dirty-check.
func register_send_handler(comp_type_name: String, handler: Callable) -> void:
	_custom_send_handlers[comp_type_name] = handler


## Server-side relay: queue validated client data into HIGH bucket so it is
## broadcast to all other clients at the next HIGH-priority flush.
func queue_relay_data(entity_id: String, comp_data: Dictionary) -> void:
	var priority: int = CN_NetSync.Priority.HIGH

	if not _pending[priority].has(entity_id):
		_pending[priority][entity_id] = {}

	# Merge component data (received relay data takes priority)
	for comp_type in comp_data.keys():
		if not _pending[priority][entity_id].has(comp_type):
			_pending[priority][entity_id][comp_type] = {}
		for prop_name in comp_data[comp_type].keys():
			_pending[priority][entity_id][comp_type][prop_name] = comp_data[comp_type][prop_name]


# ============================================================================
# PRIVATE — TIMER / FLUSH
# ============================================================================


func _flush_due_priorities() -> void:
	for priority in CN_NetSync.Priority.values():
		if not _should_flush(priority):
			continue
		# Reset timer (REALTIME interval is 0.0; resetting is harmless)
		_timers[priority] = 0.0
		_poll_entities_for_priority(priority)
		_dispatch_batch(priority)


func _should_flush(priority: int) -> bool:
	var interval: float = _get_interval(priority)
	if interval <= 0.0:
		return true  # REALTIME always flushes every tick
	return _timers[priority] >= interval


func _get_interval(priority: int) -> float:
	match priority:
		CN_NetSync.Priority.REALTIME:
			return 0.0
		CN_NetSync.Priority.HIGH:
			return 1.0 / ProjectSettings.get_setting("gecs_network/sync/high_hz", 20)
		CN_NetSync.Priority.MEDIUM:
			return 1.0 / ProjectSettings.get_setting("gecs_network/sync/medium_hz", 10)
		CN_NetSync.Priority.LOW:
			return 1.0 / ProjectSettings.get_setting("gecs_network/sync/low_hz", 2)
	return 0.0


# ============================================================================
# PRIVATE — ENTITY POLL
# ============================================================================


func _poll_entities_for_priority(priority: int) -> void:
	for entity in _ns._world.entities:
		if not is_instance_valid(entity):
			continue

		var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
		if net_id == null:
			continue  # Non-networked entity

		# Spawn-only: entities without CN_NetSync are not continuously synced
		var net_sync: CN_NetSync = entity.get_component(CN_NetSync)
		if net_sync == null:
			continue

		if not _should_broadcast(entity, net_id):
			continue

		# Determine component changes.
		# Compute default dirty-check once (advances internal cache), then apply
		# custom handler overrides: null = keep default, {} = suppress, dict = replace.
		var changes: Dictionary = net_sync.check_changes_for_priority(priority)
		if not _custom_send_handlers.is_empty():
			for inst_id in net_sync._comp_refs.keys():
				var comp = net_sync._comp_refs[inst_id]
				var comp_type: String = _get_comp_type_name(comp)
				if not _custom_send_handlers.has(comp_type):
					continue
				var result = _custom_send_handlers[comp_type].call(entity, comp, priority)
				if result == null:
					pass  # Keep default dirty-check result already in changes
				elif result is Dictionary:
					if result.is_empty():
						changes.erase(comp_type)  # {} means suppress
					else:
						changes[comp_type] = result  # Override with custom data

		if changes.is_empty():
			continue

		# Merge into pending accumulator
		if not _pending[priority].has(entity.id):
			_pending[priority][entity.id] = {}
		for comp_type in changes.keys():
			if not _pending[priority][entity.id].has(comp_type):
				_pending[priority][entity.id][comp_type] = {}
			for prop_name in changes[comp_type].keys():
				_pending[priority][entity.id][comp_type][prop_name] = changes[comp_type][prop_name]


func _should_broadcast(_entity: Entity, net_id: CN_NetworkIdentity) -> bool:
	# Server broadcasts all entities' changes
	if _ns.net_adapter.is_server():
		return true
	# Client only broadcasts changes for entities it owns
	return net_id.peer_id == _ns.net_adapter.get_my_peer_id()


# ============================================================================
# PRIVATE — BATCH DISPATCH
# ============================================================================


func _dispatch_batch(priority: int) -> void:
	if _pending[priority].is_empty():
		return

	var batch: Dictionary = _pending[priority].duplicate(true)
	_pending[priority].clear()

	var is_unreliable: bool = priority <= CN_NetSync.Priority.HIGH  # REALTIME or HIGH

	if _ns.net_adapter.is_server():
		if is_unreliable:
			_ns._send_sync_unreliable(batch)
		else:
			_ns._send_sync_reliable(batch)
	else:
		# Client sends to server only
		if is_unreliable:
			_ns._send_sync_unreliable(batch)
		else:
			_ns._send_sync_reliable(batch)


# ============================================================================
# PRIVATE — HELPERS
# ============================================================================


## Get the wire-format type name for a component instance.
## Mirrors the logic in CN_NetSync._comp_type_names for consistency.
func _get_comp_type_name(comp) -> String:
	var script = comp.get_script()
	if script == null:
		return comp.get_class()
	var ct: String = script.get_global_name()
	if ct == "":
		ct = script.resource_path.get_file().get_basename()
	return ct
