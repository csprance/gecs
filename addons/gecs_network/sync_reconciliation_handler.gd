extends RefCounted
## SyncReconciliationHandler — periodic full-state broadcast for ADV-02.
##
## Wired into NetworkSync._process() via tick(delta).
## Server-only: clients only receive and apply reconciliation state.
## Uses _ns._spawn_manager.serialize_entity() for serialization (handles all
## component types including relationships).
## Routes application through _ns._receiver._apply_component_data() to
## preserve _applying_network_data guard and update_cache_silent() calls.

var _ns       # NetworkSync reference (untyped)
var _timer: float = 0.0

## When > 0.0, overrides ProjectSettings reconciliation_interval for this session.
## When <= 0.0, auto-reconciliation is disabled (set by NetworkSync.reconciliation_interval).
## Default -1.0 means "use ProjectSettings value".
var _override_interval: float = -1.0


func _init(network_sync) -> void:
	_ns = network_sync


func tick(delta: float) -> void:
	if not _ns.net_adapter.is_server():
		return

	# Resolve effective interval
	var interval: float
	if _override_interval > 0.0:
		interval = _override_interval
	elif _override_interval == 0.0:
		return  # Explicitly disabled
	else:
		# _override_interval < 0.0: use ProjectSettings default
		interval = ProjectSettings.get_setting(
			"gecs_network/sync/reconciliation_interval", 30.0
		)

	_timer += delta
	if _timer >= interval:
		_timer = 0.0
		broadcast_full_state()


func broadcast_full_state() -> void:
	if not _ns.net_adapter.is_server():
		return

	var full_state: Array = []
	for entity in _ns._world.entities:
		if not is_instance_valid(entity):
			continue
		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue
		full_state.append(_ns._spawn_manager.serialize_entity(entity))

	if full_state.is_empty():
		return

	var payload := {"entities": full_state, "session_id": _ns._game_session_id}
	_ns.rpc("_sync_full_state", payload)


func handle_sync_full_state(payload: Dictionary) -> void:
	if payload.get("session_id", -1) != _ns._game_session_id:
		return  # Stale session — reject

	var server_entities: Array = payload.get("entities", [])

	# Build set of known server entity IDs for ghost detection
	var server_ids: Dictionary = {}
	for entity_data in server_entities:
		server_ids[entity_data.get("id", "")] = true

	# Apply component data for known entities; skip local (own) entities
	var my_peer_id: int = _ns.net_adapter.get_my_peer_id()
	for entity_data in server_entities:
		var entity_id: String = entity_data.get("id", "")
		var entity = _ns._world.entity_id_registry.get(entity_id)
		if entity == null:
			continue  # Entity not yet spawned; spawn path handles this
		var net_id = entity.get_component(CN_NetworkIdentity)
		if net_id == null:
			continue
		if net_id.peer_id == my_peer_id:
			continue  # Never overwrite own entity — CRITICAL
		var comp_data: Dictionary = entity_data.get("components", {})
		if not comp_data.is_empty():
			_ns._receiver._apply_component_data(entity, comp_data)

	# Remove ghost entities: present locally but absent from server state
	# Collect first to avoid modifying world.entities during iteration
	var ghosts: Array = []
	for entity in _ns._world.entities:
		if not is_instance_valid(entity):
			continue
		var net_id = entity.get_component(CN_NetworkIdentity)
		if net_id == null:
			continue
		if net_id.peer_id == my_peer_id:
			continue  # Never remove own entity
		if not server_ids.has(entity.id):
			ghosts.append(entity)

	for ghost in ghosts:
		if is_instance_valid(ghost):
			if _ns.debug_logging:
				print("[GECS Network] Reconciliation: removing ghost entity '%s' (absent from server state)" % ghost.id)
			_ns._world.remove_entity(ghost)
