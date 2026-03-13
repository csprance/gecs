class_name NetworkSync
extends Node
## NetworkSync - Phase 1 skeleton: RPC surface for entity lifecycle.
##
## Attaches to a GECS World to enable multiplayer synchronization.
## Phase 1 covers spawn/despawn/world-state lifecycle only.
## Phase 2-5 handlers (property sync, native sync, relationship sync,
## state/time sync, reconciliation) are intentionally absent.
##
## Architecture:
## - NetworkSync is the ONLY node that declares @rpc methods (Godot requirement)
## - SpawnManager handles all entity lifecycle logic; NetworkSync delegates to it
## - is_in_game() guard in _process() ensures zero overhead in single-player
##
## Four critical invariants (must never regress):
## 1. Node name is "NetworkSync" before add_child() and via _ready() fallback guard
## 2. Every lifecycle RPC includes session_id to reject stale cross-game calls
## 3. _process() returns immediately when not in game
## 4. _applying_network_data flag prevents sync loops when applying received data
##
## Usage (recommended):
##   var net_sync = NetworkSync.attach_to_world(world)
##
## Or manual (name guard in _ready() handles this):
##   var net_sync = NetworkSync.new()
##   world.add_child(net_sync)

## Emitted when any entity is spawned on a client (after component data is applied)
signal entity_spawned(entity: Entity)

## Emitted when the local player's entity is spawned (clients use for UI setup)
signal local_player_spawned(entity: Entity)

# ============================================================================
# CONFIGURATION
# ============================================================================

## Network adapter for multiplayer operations.
## If not provided, a default NetAdapter is created in _ready().
@export var net_adapter: NetAdapter

## Debug logging
@export var debug_logging: bool = false

# ============================================================================
# INTERNAL STATE (Phase 1 invariants — must never be removed)
# ============================================================================

var _world: World
var _applying_network_data: bool = false  # Prevents sync loops — CRITICAL
var _broadcast_pending: Dictionary = {}   # Deferred spawn guard — CRITICAL
var _spawn_counter: int = 0
var _game_session_id: int = 0             # Session anti-ghost — CRITICAL
var _spawn_manager: SpawnManager
var _sender: SyncSender
var _receiver: SyncReceiver
var _native_sync_handler: NativeSyncHandler
var _relationship_handler  # SyncRelationshipHandler (untyped — no class_name)
var _reconciliation_handler  # SyncReconciliationHandler (untyped — no class_name)
var _is_ready: bool = false

# ============================================================================
# STATIC FACTORY METHOD
# ============================================================================


## Attach NetworkSync to a World with an optional NetAdapter.
## CRITICAL: sets name before add_child() so RPC routing is consistent across peers.
static func attach_to_world(world: World, net_adapter: NetAdapter = null) -> NetworkSync:
	var net_sync = NetworkSync.new()
	net_sync.name = "NetworkSync"  # CRITICAL for RPC routing
	if net_adapter != null:
		net_sync.net_adapter = net_adapter
	world.add_child(net_sync)
	return net_sync


# ============================================================================
# LIFECYCLE
# ============================================================================


func _ready() -> void:
	# Fallback name guard — ensures RPC routing works even when not using factory
	if name.begins_with("@"):
		name = "NetworkSync"  # CRITICAL

	if net_adapter == null:
		net_adapter = NetAdapter.new()

	_world = get_parent() as World
	if _world == null:
		push_error("NetworkSync: parent must be a World node")
		return

	_spawn_manager = SpawnManager.new(self)
	_sender = SyncSender.new(self)
	_receiver = SyncReceiver.new(self)
	_native_sync_handler = NativeSyncHandler.new(self)
	var SyncRelationshipHandlerScript = load("res://addons/gecs_network/sync_relationship_handler.gd")
	_relationship_handler = SyncRelationshipHandlerScript.new(self)
	var SyncReconciliationHandlerScript = load("res://addons/gecs_network/sync_reconciliation_handler.gd")
	_reconciliation_handler = SyncReconciliationHandlerScript.new(self)

	_world.entity_added.connect(_on_entity_added)
	_world.entity_removed.connect(_on_entity_removed)

	if net_adapter.is_in_game():
		_connect_multiplayer_signals()

	_is_ready = true


func _exit_tree() -> void:
	_disconnect_multiplayer_signals()

	if _world:
		if _world.entity_added.is_connected(_on_entity_added):
			_world.entity_added.disconnect(_on_entity_added)
		if _world.entity_removed.is_connected(_on_entity_removed):
			_world.entity_removed.disconnect(_on_entity_removed)


## Reset NetworkSync state for a new game instance.
## Call this when returning to lobby/menu to ensure clean state for next game.
func reset_for_new_game() -> void:
	_game_session_id += 1  # Monotonic increment invalidates all in-flight RPCs
	_broadcast_pending.clear()
	_spawn_counter = 0
	if _relationship_handler != null:
		_relationship_handler.reset()

	if debug_logging:
		print("NetworkSync: reset_for_new_game() session_id=%d" % _game_session_id)


# ============================================================================
# PUBLIC API — Reconciliation (ADV-02)
# ============================================================================

## Runtime override for the reconciliation interval (seconds).
## Overrides the ProjectSettings value for the current session.
## Set to 0.0 or negative to disable automatic reconciliation.
## Default: -1.0 (uses gecs_network/sync/reconciliation_interval ProjectSetting = 30.0).
var reconciliation_interval: float:
	get:
		if _reconciliation_handler == null:
			return ProjectSettings.get_setting(
				"gecs_network/sync/reconciliation_interval", 30.0
			)
		return _reconciliation_handler._override_interval
	set(value):
		if _reconciliation_handler == null:
			push_warning("NetworkSync: reconciliation_interval set before _ready()")
			return
		_reconciliation_handler._override_interval = value
		# Reset timer so new interval takes effect from now, not mid-accumulation
		_reconciliation_handler._timer = 0.0


## Trigger an immediate full-state reconciliation broadcast.
## Server-only; no-op on clients.
## Use for reconnect flows or after significant world state changes.
func broadcast_full_state() -> void:
	if _reconciliation_handler == null:
		push_warning("NetworkSync: broadcast_full_state() called before _ready()")
		return
	_reconciliation_handler.broadcast_full_state()


# ============================================================================
# PUBLIC API — Custom Sync Handlers (ADV-03)
# ============================================================================

## Register a custom send handler for a component type.
## The handler is called instead of the default dirty-check for the named component type.
##
## Callable signature:
##   func(entity: Entity, comp: Component, priority: int) -> Dictionary
##   Return: { prop: value } to send, {} to suppress, null to use default dirty-check.
##
## Example (client-side prediction — send only what local entity needs):
##   func _ready() -> void:
##       var ns := ECS.world.get_node("NetworkSync") as NetworkSync
##       ns.register_send_handler("C_PlayerInput", _send_predicted_input)
##
##   func _send_predicted_input(entity: Entity, comp: Component, priority: int) -> Dictionary:
##       if entity.has_component(CN_LocalAuthority):
##           return {"move_dir": comp.move_dir, "jump_pressed": comp.jump_pressed}
##       return {}  # Suppress for non-local entities
##
## See also: addons/gecs_network/docs/custom-sync-handlers.md
func register_send_handler(comp_type_name: String, handler: Callable) -> void:
	if _sender == null:
		push_error("NetworkSync: register_send_handler called before _ready()")
		return
	_sender.register_send_handler(comp_type_name, handler)


## Register a custom receive handler for a component type.
## The handler is called instead of the default comp.set() for the named component type.
## The framework ALWAYS calls update_cache_silent() after the handler (prevents echo loops).
##
## Callable signature:
##   func(entity: Entity, comp: Component, props: Dictionary) -> bool
##   Return: true if handled (skip default set()), false to fall through to default.
##
## Example (server correction blending for prediction):
##   func _ready() -> void:
##       var ns := ECS.world.get_node("NetworkSync") as NetworkSync
##       ns.register_receive_handler("C_Position", _blend_server_correction)
##
##   func _blend_server_correction(entity: Entity, comp: Component, props: Dictionary) -> bool:
##       if props.has("position"):
##           comp.position = comp.position.lerp(props["position"], 0.3)
##       return true  # Handled — update_cache_silent will be called by framework
##
## See also: addons/gecs_network/docs/custom-sync-handlers.md
func register_receive_handler(comp_type_name: String, handler: Callable) -> void:
	if _receiver == null:
		push_error("NetworkSync: register_receive_handler called before _ready()")
		return
	_receiver.register_receive_handler(comp_type_name, handler)


func _process(delta: float) -> void:
	if _world == null or not net_adapter.is_in_game():
		return  # Zero overhead in single-player — FOUND-03
	_sender.tick(delta)  # Phase 2: priority-tiered property sync
	if _reconciliation_handler != null:
		_reconciliation_handler.tick(delta)


# ============================================================================
# MULTIPLAYER SIGNAL CONNECTIONS
# ============================================================================


func _connect_multiplayer_signals() -> void:
	var mp = net_adapter.get_multiplayer()
	if mp == null:
		return
	if not mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.connect(_on_peer_connected)
	if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.connect(_on_peer_disconnected)


func _disconnect_multiplayer_signals() -> void:
	var mp = net_adapter.get_multiplayer()
	if mp == null:
		return
	if mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.disconnect(_on_peer_connected)
	if mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.disconnect(_on_peer_disconnected)


# ============================================================================
# WORLD SIGNAL HANDLERS
# ============================================================================


func _on_entity_added(entity: Entity) -> void:
	if not net_adapter.is_in_game():
		return
	# Server-only: queue deferred spawn broadcast
	if net_adapter.is_server():
		_spawn_manager.on_entity_added(entity)
	# All peers: wire relationship signals + attempt deferred resolution
	if _relationship_handler != null:
		entity.relationship_added.connect(_relationship_handler.on_relationship_added)
		entity.relationship_removed.connect(_relationship_handler.on_relationship_removed)
		_relationship_handler.try_resolve_pending(entity)


func _on_entity_removed(entity: Entity) -> void:
	if not net_adapter.is_in_game():
		return
	_spawn_manager.on_entity_removed(entity)


# ============================================================================
# MULTIPLAYER SIGNAL HANDLERS
# ============================================================================


func _on_peer_connected(peer_id: int) -> void:
	if not net_adapter.is_server() or _world == null:
		return
	var state = _spawn_manager.serialize_world_state()
	_sync_world_state.rpc_id(peer_id, state)
	# Deferred so spawn RPC fires first, then synchronizers refresh for new peer
	call_deferred("_deferred_refresh_visibility")


func _on_peer_disconnected(peer_id: int) -> void:
	if not net_adapter.is_server() or _world == null:
		return
	_spawn_manager.on_peer_disconnected(peer_id)


func _deferred_refresh_visibility() -> void:
	if _native_sync_handler != null:
		_native_sync_handler.refresh_synchronizer_visibility()


# ============================================================================
# DEFERRED BROADCAST HELPERS (called by SpawnManager via call_deferred)
# ============================================================================


## Called deferred by SpawnManager.on_entity_added after all components are set.
## Validates the entity is still pending and still valid before broadcasting.
func _deferred_broadcast(entity: Entity, entity_id: String) -> void:
	if not is_instance_valid(entity):
		_broadcast_pending.erase(entity_id)
		return
	if not _broadcast_pending.has(entity_id):
		return  # Cancelled by on_entity_removed before deferred call fired
	_broadcast_pending.erase(entity_id)
	# Server-side setup: inject authority markers and native sync.
	# Clients receive these via _apply_component_data in handle_spawn_entity.
	# The server never receives its own spawn RPCs, so we do it here.
	var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
	if net_id:
		_spawn_manager._inject_authority_markers(entity, net_id)
	if _native_sync_handler != null:
		_native_sync_handler.setup_native_sync(entity)
	var data = _spawn_manager.serialize_entity(entity)
	_spawn_entity.rpc(data)


## Called directly by SpawnManager.on_entity_removed to broadcast a despawn.
## Public so SpawnManager (a RefCounted) can call it via the _ns reference.
func rpc_broadcast_despawn(entity_id: String, session_id: int) -> void:
	_despawn_entity.rpc(entity_id, session_id)


# ============================================================================
# SEND HELPERS — called by SyncSender to dispatch component sync batches.
# Separate from the @rpc receivers so SyncSender remains testable with mocks.
# Server path: broadcasts to all connected clients.
# Client path: sends to server (peer 1) only.
# ============================================================================


## Send an unreliable component sync batch.
## Server: broadcasts to all clients. Client: sends to server only.
func _send_sync_unreliable(batch: Dictionary) -> void:
	if net_adapter.is_server():
		_sync_components_unreliable.rpc(batch)
	else:
		_sync_components_unreliable.rpc_id(1, batch)


## Send a reliable component sync batch.
## Server: broadcasts to all clients. Client: sends to server only.
func _send_sync_reliable(batch: Dictionary) -> void:
	if net_adapter.is_server():
		_sync_components_reliable.rpc(batch)
	else:
		_sync_components_reliable.rpc_id(1, batch)


# ============================================================================
# RPC DECLARATIONS — all @rpc methods must live on this Node (Godot requirement)
# ============================================================================


@rpc("authority", "reliable")
func _spawn_entity(data: Dictionary) -> void:
	if _spawn_manager == null:
		return
	_spawn_manager.handle_spawn_entity(data)


@rpc("authority", "reliable")
func _despawn_entity(entity_id: String, session_id: int) -> void:
	if _spawn_manager == null:
		return
	_spawn_manager.handle_despawn_entity(entity_id, session_id)


@rpc("authority", "reliable")
func _sync_world_state(state: Dictionary) -> void:
	if _spawn_manager == null:
		return
	_spawn_manager.handle_world_state(state)


@rpc("any_peer", "unreliable_ordered")
func _sync_components_unreliable(batch: Dictionary) -> void:
	if _receiver == null:
		return
	_receiver.handle_apply_sync_data(batch)


@rpc("any_peer", "reliable")
func _sync_components_reliable(batch: Dictionary) -> void:
	if _receiver == null:
		return
	_receiver.handle_apply_sync_data(batch)


@rpc("any_peer", "reliable")
func _sync_relationship_add(payload: Dictionary) -> void:
	if _relationship_handler == null:
		return
	_relationship_handler.handle_relationship_add(payload)


@rpc("any_peer", "reliable")
func _sync_relationship_remove(payload: Dictionary) -> void:
	if _relationship_handler == null:
		return
	_relationship_handler.handle_relationship_remove(payload)


@rpc("authority", "reliable")
func _sync_full_state(payload: Dictionary) -> void:
	if _reconciliation_handler == null:
		return
	_reconciliation_handler.handle_sync_full_state(payload)
