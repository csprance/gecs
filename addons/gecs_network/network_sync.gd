class_name NetworkSync
extends Node
## NetworkSync - Attaches to a GECS World to enable multiplayer synchronization.
##
## Add as a child of your World node. Both server and clients use this node -
## behavior differs based on entity authority (CN_NetworkIdentity.peer_id).
##
## Architecture:
## - Server and clients run IDENTICAL systems
## - Server is authoritative - holds "true" data
## - Local player can modify own data - responsive movement
## - Component data sync drives everything
##
## Usage:
##   # One-line setup (recommended):
##   var net_sync = NetworkSync.attach_to_world(world)
##
##   # Or manual setup (name is set automatically in _ready if needed):
##   var network_sync = NetworkSync.new()
##   world.add_child(network_sync)
##
## IMPORTANT: The node name must be consistent across all peers for RPCs to work.
## The factory method and _ready() handle this automatically.

## Emitted when a player entity is spawned for the local peer (clients can use this for UI setup)
signal local_player_spawned(entity: Entity)

## Emitted when any entity is spawned on a client (after component data is applied)
## Projects can connect to this to apply visual properties from components
signal entity_spawned(entity: Entity)

# ============================================================================
# CONFIGURATION
# ============================================================================

## Network adapter for multiplayer operations.
## If not provided, uses default Godot multiplayer.
@export var net_adapter: NetAdapter

## Sync priority configuration resource
@export var sync_config: SyncConfig

## Debug logging
@export var debug_logging: bool = false

# ============================================================================
# INTERNAL STATE
# ============================================================================

var _world: World
# Priority -> {entity_id -> {component_type -> {property -> value}}}
var _pending_updates_by_priority: Dictionary = {}
var _sync_timers: Dictionary = {}  # SyncPriority -> float (accumulated time)
var _entity_connections: Dictionary = {}  # entity -> Array[Callable] (for cleanup)
var _applying_network_data: bool = false  # Flag to prevent sync loops when applying received data

# Deferred setup state
var _pending_entity_setup: Array[Entity] = []  # Entities waiting for connection
var _is_ready: bool = false  # True after _ready() completes

# Spawn deduplication (prevents double-broadcast from call_deferred)
var _broadcast_pending: Dictionary = {}  # entity_id -> true (cleared after broadcast)

# Server time synchronization
var _server_time_offset: float = 0.0  # local_time + offset = server_time
var _ping_interval: float = 5.0  # Sync time every 5 seconds
var _ping_timer: float = 0.0
var _ping_counter: int = 0  # Monotonic counter for collision-free ping IDs
var _pending_pings: Dictionary = {}  # ping_id -> send_time (for RTT calculation)
var _time_sync_initialized: bool = false

# Entity ID generation
var _spawn_counter: int = 0

# Game session tracking (prevents stale spawn RPCs after game reset)
var _game_session_id: int = 0

# Reconciliation
var _reconciliation_timer: float = 0.0

# Component type name cache: entity instance_id -> { comp_type_name -> Component }
var _comp_type_cache: Dictionary = {}

# Index of entities with SyncComponents for efficient polling.
# Maps entity instance_id -> { "entity": Entity, "sync_comps": Array[SyncComponent] }
# Only includes entities with CN_NetworkIdentity that we have authority to broadcast.
var _sync_entity_index: Dictionary = {}

# Native sync diagnostic tracking
var _sync_diagnostic_timer: float = 0.0
const SYNC_DIAGNOSTIC_INTERVAL: float = 2.0  # Log sync status every 2 seconds

# Entity count diagnostic tracking
var _entity_count_timer: float = 0.0
const ENTITY_COUNT_INTERVAL: float = 5.0  # Log entity counts every 5 seconds

# ============================================================================
# HANDLER HELPERS (internal, not part of public API)
# ============================================================================

const SyncSpawnHandler = preload("res://addons/gecs_network/sync_spawn_handler.gd")
const SyncNativeHandler = preload("res://addons/gecs_network/sync_native_handler.gd")
const SyncPropertyHandler = preload("res://addons/gecs_network/sync_property_handler.gd")
const SyncStateHandler = preload("res://addons/gecs_network/sync_state_handler.gd")
const SyncRelationshipHandler = preload("res://addons/gecs_network/sync_relationship_handler.gd")

var _spawn_handler  # SyncSpawnHandler
var _native_handler  # SyncNativeHandler
var _property_handler  # SyncPropertyHandler
var _state_handler  # SyncStateHandler
var _relationship_handler  # SyncRelationshipHandler

# ============================================================================
# STATIC FACTORY METHOD
# ============================================================================


## Attach NetworkSync to a World with optional configuration.
## This is the recommended way to set up networking.
## @param world: The GECS World node
## @param config: Optional SyncConfig (uses smart defaults if null)
## @param adapter: Optional NetAdapter (uses Godot multiplayer if null)
## @return: The configured NetworkSync instance
static func attach_to_world(
	world: World, config: SyncConfig = null, adapter: NetAdapter = null
) -> NetworkSync:
	var net_sync = NetworkSync.new()
	# CRITICAL: Set a consistent name so RPC paths match across all peers
	# Without this, Godot auto-generates names like "@Node@15" which differ
	# between server and clients, causing RPC failures
	net_sync.name = "NetworkSync"

	if config != null:
		net_sync.sync_config = config
	if adapter != null:
		net_sync.net_adapter = adapter

	world.add_child(net_sync)
	return net_sync


# ============================================================================
# LIFECYCLE
# ============================================================================


func _ready() -> void:
	# Ensure consistent name for RPC routing (fallback if not using factory method)
	if name.begins_with("@"):
		name = "NetworkSync"

	_init_adapter()
	_init_sync_config()

	_world = get_parent() as World
	if _world == null:
		push_error(
			"NetworkSync: Parent node is not a World. NetworkSync must be a child of a World node."
		)
		queue_free()
		return

	# Initialize handler helpers BEFORE connecting signals
	_spawn_handler = SyncSpawnHandler.new(self)
	_native_handler = SyncNativeHandler.new(self)
	_property_handler = SyncPropertyHandler.new(self)
	_state_handler = SyncStateHandler.new(self)
	_relationship_handler = SyncRelationshipHandler.new(self)

	if debug_logging:
		print(
			(
				"NetworkSync initialized, is_server=%s, peer_id=%d"
				% [net_adapter.is_server(), net_adapter.get_my_peer_id()]
			)
		)

	# Initialize sync timers and priority batches
	for priority in SyncConfig.Priority.values():
		_sync_timers[priority] = 0.0
		_pending_updates_by_priority[priority] = {}

	# Connect to World signals
	_world.entity_added.connect(_on_entity_added)
	_world.entity_removed.connect(_on_entity_removed)
	_world.component_added.connect(_on_component_added)
	_world.component_removed.connect(_on_component_removed)
	_world.relationship_added.connect(_on_relationship_added)
	_world.relationship_removed.connect(_on_relationship_removed)

	# Connect multiplayer signals
	_connect_multiplayer_signals()

	# Connect to existing entities (in case NetworkSync is added after entities)
	for entity in _world.entities:
		_connect_entity_signals(entity)

	# Mark as ready
	_is_ready = true

	# Process any pending entities
	_process_pending_entities()


func _exit_tree() -> void:
	# Disconnect multiplayer signals
	_disconnect_multiplayer_signals()

	# Disconnect world signals
	if _world:
		if _world.entity_added.is_connected(_on_entity_added):
			_world.entity_added.disconnect(_on_entity_added)
		if _world.entity_removed.is_connected(_on_entity_removed):
			_world.entity_removed.disconnect(_on_entity_removed)
		if _world.component_added.is_connected(_on_component_added):
			_world.component_added.disconnect(_on_component_added)
		if _world.component_removed.is_connected(_on_component_removed):
			_world.component_removed.disconnect(_on_component_removed)
		if _world.relationship_added.is_connected(_on_relationship_added):
			_world.relationship_added.disconnect(_on_relationship_added)
		if _world.relationship_removed.is_connected(_on_relationship_removed):
			_world.relationship_removed.disconnect(_on_relationship_removed)

	# Disconnect from all entities
	for entity in _entity_connections.keys():
		_disconnect_entity_signals(entity)
	_entity_connections.clear()


## Reset NetworkSync state for a new game instance.
## Call this when returning to lobby/menu to ensure clean state for next game.
func reset_for_new_game() -> void:
	# Increment session ID to invalidate any in-flight spawn RPCs from previous game
	var old_session = _game_session_id
	_game_session_id += 1

	# Always log session changes for debugging
	var prefix = "SERVER" if net_adapter.is_server() else "CLIENT"
	var peer_id = net_adapter.get_my_peer_id()
	print(
		(
			"[SESSION-SYNC] %s (peer %d): reset_for_new_game() session_id: %d -> %d"
			% [prefix, peer_id, old_session, _game_session_id]
		)
	)

	# Clear all pending updates
	for priority in _pending_updates_by_priority.keys():
		_pending_updates_by_priority[priority] = {}

	# Clear pending entity setup queue
	_pending_entity_setup.clear()

	# Clear pending broadcast entries from previous game session
	_broadcast_pending.clear()

	# Reset sync timers
	for priority in _sync_timers.keys():
		_sync_timers[priority] = 0.0

	# Reset time sync (will re-sync when new game starts)
	_time_sync_initialized = false
	_ping_timer = 0.0
	_ping_counter = 0
	_pending_pings.clear()
	_comp_type_cache.clear()
	_sync_entity_index.clear()

	# Reset reconciliation timer
	_reconciliation_timer = 0.0

	# Reset spawn counter for deterministic IDs
	_spawn_counter = 0

	# Reset relationship handler state
	_relationship_handler.reset()

	# Disconnect from existing entities (they will be cleaned up)
	for entity in _entity_connections.keys():
		_disconnect_entity_signals(entity)
	_entity_connections.clear()

	if debug_logging:
		print("NetworkSync: State reset complete")


func _process(delta: float) -> void:
	if _world == null or not net_adapter.is_in_game():
		return

	# Server time synchronization (clients only)
	_state_handler.sync_server_time(delta)

	# Update sync timers
	_property_handler.update_sync_timers(delta)

	# Send pending updates (priority-batched)
	_property_handler.send_pending_updates_batched()

	# Native sync diagnostics (periodic logging to verify sync is working)
	_state_handler.process_sync_diagnostics(delta)

	# Entity count diagnostics (to track desync)
	_state_handler.process_entity_count_diagnostics(delta)

	# Reconciliation (server only)
	_state_handler.process_reconciliation(delta)


# ============================================================================
# INITIALIZATION HELPERS
# ============================================================================


func _init_adapter() -> void:
	if net_adapter == null:
		net_adapter = NetAdapter.new()
		if debug_logging:
			print("Using default NetAdapter")


func _init_sync_config() -> void:
	if sync_config == null:
		sync_config = _create_default_config()
		if debug_logging:
			print("Using default SyncConfig")


func _create_default_config() -> SyncConfig:
	var config = SyncConfig.new()
	# NO component priorities - projects must provide their own SyncConfig
	# The addon provides empty defaults to remain project-agnostic
	# See sync_config.gd for documentation on configuration options
	return config


# ============================================================================
# MULTIPLAYER SIGNAL CONNECTIONS
# ============================================================================


func _connect_multiplayer_signals() -> void:
	var mp = net_adapter.multiplayer
	if mp == null:
		return

	if not mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.connect(_on_peer_connected)
	if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.connect(_on_peer_disconnected)
	if not mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.connect(_on_connected_to_server)
	if not mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.connect(_on_connection_failed)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)


func _disconnect_multiplayer_signals() -> void:
	var mp = net_adapter.multiplayer
	if mp == null:
		return

	if mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.disconnect(_on_peer_connected)
	if mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.disconnect(_on_peer_disconnected)
	if mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.disconnect(_on_connected_to_server)
	if mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.disconnect(_on_connection_failed)
	if mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.disconnect(_on_server_disconnected)


# ============================================================================
# MULTIPLAYER SIGNAL HANDLERS (Late Join Support)
# ============================================================================


func _on_peer_connected(peer_id: int) -> void:
	if not net_adapter.is_server() or _world == null:
		return

	# Send full world state to new peer (includes session_id for sync)
	var state = _spawn_handler.serialize_world_state()
	print(
		(
			"[SESSION-SYNC] SERVER: Sending world state to peer %d (session_id=%d, entities=%d)"
			% [peer_id, _game_session_id, state.get("entities", []).size()]
		)
	)
	_sync_world_state.rpc_id(peer_id, state)

	# Force existing MultiplayerSynchronizers to update their peer visibility
	# This ensures existing entities sync to the newly connected peer
	_native_handler.refresh_synchronizer_visibility()

	# Notify all clients to refresh their synchronizers for the new peer
	# This handles the case where client A's synchronizer needs to sync to new client B
	_notify_peers_to_refresh.rpc()

	# Also send current positions via RPC as a failsafe
	# This ensures the reconnecting client gets accurate positions even if native sync delays
	call_deferred("_deferred_send_position_snapshot", peer_id)

	# Log sync status for debugging
	call_deferred("_deferred_log_sync_status")


func _on_peer_disconnected(peer_id: int) -> void:
	if debug_logging:
		print("Peer %d disconnected" % peer_id)

	if not net_adapter.is_server() or _world == null:
		return

	# Remove entities owned by disconnected peer
	var entities_to_remove: Array[Entity] = []
	for entity in _world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if net_id and net_id.peer_id == peer_id:
			entities_to_remove.append(entity)

	for entity in entities_to_remove:
		if debug_logging:
			print("Removing entity owned by disconnected peer: %s" % entity.id)
		_world.remove_entity(entity)
		# Free the node from scene tree (remove_entity only removes from ECS world)
		if is_instance_valid(entity):
			entity.queue_free()


func _on_connected_to_server() -> void:
	if debug_logging:
		print("Connected to server")

	# Process any pending entities now that we're connected
	_process_pending_entities()

	# Log sync status for debugging (deferred to allow entity setup to complete)
	call_deferred("_deferred_log_sync_status")


func _on_connection_failed() -> void:
	if debug_logging:
		print("Connection to server failed")

	# Clear pending entities
	_pending_entity_setup.clear()


func _on_server_disconnected() -> void:
	if debug_logging:
		print("Server disconnected")

	if _world == null:
		return

	# Clear all networked entities
	var entities_to_remove: Array[Entity] = []
	for entity in _world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if net_id:
			entities_to_remove.append(entity)

	for entity in entities_to_remove:
		_world.remove_entity(entity)
		# Free the node from scene tree (remove_entity only removes from ECS world)
		if is_instance_valid(entity):
			entity.queue_free()


# ============================================================================
# DEFERRED ENTITY SETUP
# ============================================================================


func _process_pending_entities() -> void:
	if _pending_entity_setup.is_empty():
		return

	if debug_logging:
		print("Processing %d pending entities" % _pending_entity_setup.size())

	var entities_to_process = _pending_entity_setup.duplicate()
	_pending_entity_setup.clear()

	for entity in entities_to_process:
		if is_instance_valid(entity):
			_state_handler.auto_assign_markers(entity)
			# Only setup native sync if target_node is explicitly set (model instantiated)
			# Otherwise, _on_component_added will handle it when model_ready_component is added
			var sync_comp = entity.get_component(CN_SyncEntity)
			if sync_comp and sync_comp.target_node != null:
				_native_handler.auto_setup_native_sync(entity)


# ============================================================================
# WORLD SIGNAL HANDLERS (orchestrators)
# ============================================================================


func _on_entity_added(entity: Entity) -> void:
	_connect_entity_signals(entity)

	# Check if we should defer setup
	if not _is_ready or not net_adapter.is_in_game():
		if entity.has_component(CN_NetworkIdentity):
			if not _pending_entity_setup.has(entity):
				_pending_entity_setup.append(entity)
				if debug_logging:
					print("Queued entity for deferred setup: %s" % entity.id)
		return

	# Auto-assign markers (native sync is deferred until model is instantiated)
	_state_handler.auto_assign_markers(entity)
	# NOTE: _auto_setup_native_sync is called from _on_component_added when model_ready_component
	# is added, ensuring the sync target exists for proper native sync setup

	# Resolve any pending relationships waiting for this entity as target
	_relationship_handler.try_resolve_pending(entity)

	# Only server broadcasts spawns
	if not net_adapter.is_server():
		return

	# Check if entity has network identity
	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# IMPORTANT: Defer spawn broadcast to end of frame.
	# This allows component values to be set AFTER add_entity() is called.
	# Without this, spawn RPC would be sent with default component values.
	# Use a pending flag to prevent duplicate broadcasts.
	if not _broadcast_pending.has(entity.id):
		_broadcast_pending[entity.id] = true
		# Pass entity.id to avoid accessing potentially invalid instance later
		call_deferred("_deferred_broadcast_entity_spawn", entity, entity.id)


func _on_entity_removed(entity: Entity) -> void:
	_disconnect_entity_signals(entity)
	_invalidate_comp_type_cache(entity)
	_remove_from_sync_entity_index(entity)

	# Clean up MultiplayerSynchronizer BEFORE entity is freed
	# This prevents "Node not found" errors from stale sync data
	_native_handler.cleanup_synchronizer(entity)

	# Remove from pending if queued
	var idx = _pending_entity_setup.find(entity)
	if idx >= 0:
		_pending_entity_setup.remove_at(idx)

	# Only server broadcasts despawns
	if not net_adapter.is_server():
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return

	# Check if spawn broadcast is still pending (entity removed before spawn was sent to clients)
	# If so, cancel the pending spawn and DON'T send despawn - entity never existed on clients
	if _broadcast_pending.has(entity.id):
		_broadcast_pending.erase(entity.id)
		if debug_logging:
			print(
				(
					"[SPAWN-TRACK] SERVER SPAWN CANCELLED (removed before broadcast): entity=%s, name=%s"
					% [entity.id, entity.name]
				)
			)
		return  # Don't send despawn - clients never received spawn

	# DIAGNOSTIC: Always log despawn broadcasts for tracking desync issues
	if debug_logging:
		print(
			(
				"[SPAWN-TRACK] SERVER DESPAWN BROADCAST: entity=%s, name=%s, session=%d"
				% [entity.id, entity.name, _game_session_id]
			)
		)
	_despawn_entity.rpc(entity.id, _game_session_id)


func _on_component_added(entity: Entity, component: Resource) -> void:
	_invalidate_comp_type_cache(entity)
	if component is SyncComponent or component is CN_NetworkIdentity:
		_update_sync_entity_index(entity)
	_property_handler.on_component_added(entity, component)


func _on_relationship_added(entity: Entity, relationship: Relationship) -> void:
	_relationship_handler.on_relationship_added(entity, relationship)


func _on_relationship_removed(entity: Entity, relationship: Relationship) -> void:
	_relationship_handler.on_relationship_removed(entity, relationship)


func _on_component_removed(entity: Entity, component: Resource) -> void:
	_invalidate_comp_type_cache(entity)
	if component is SyncComponent or component is CN_NetworkIdentity:
		_update_sync_entity_index(entity)
	_property_handler.on_component_removed(entity, component)


# ============================================================================
# ENTITY SIGNAL MANAGEMENT
# ============================================================================


func _connect_entity_signals(entity: Entity) -> void:
	if _entity_connections.has(entity):
		return  # Already connected

	var callback = func(ent: Entity, comp: Resource, prop: String, old_val, new_val):
		_property_handler.on_component_property_changed(ent, comp, prop, old_val, new_val)

	entity.component_property_changed.connect(callback)
	_entity_connections[entity] = [callback]


func _disconnect_entity_signals(entity: Entity) -> void:
	if not _entity_connections.has(entity):
		return

	var callbacks = _entity_connections[entity]
	for callback in callbacks:
		if entity.component_property_changed.is_connected(callback):
			entity.component_property_changed.disconnect(callback)

	_entity_connections.erase(entity)


# ============================================================================
# DEFERRED CALL WRAPPERS
# ============================================================================


func _deferred_broadcast_entity_spawn(entity: Entity, entity_id: String) -> void:
	_spawn_handler.broadcast_entity_spawn(entity, entity_id)


func _deferred_send_position_snapshot(peer_id: int) -> void:
	_native_handler.send_position_snapshot(peer_id)


func _deferred_log_sync_status() -> void:
	_native_handler.log_sync_status()


# ============================================================================
# SHARED UTILITY METHODS
# ============================================================================


func _find_component_by_type(entity: Entity, comp_type: String) -> Component:
	var eid = entity.get_instance_id()
	var type_map: Dictionary = _comp_type_cache.get(eid, {})
	if type_map.has(comp_type):
		var cached = type_map[comp_type]
		# Validate the cached component is still on this entity
		if is_instance_valid(cached) and entity.components.has(cached.get_script().resource_path):
			return cached
		# Stale entry — rebuild below
		type_map.erase(comp_type)

	# Linear scan (cold path)
	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		var script = comp.get_script()
		if script == null:
			continue
		var global_name = script.get_global_name()
		# Fallback to filename if class_name not declared
		if global_name == "":
			global_name = script.resource_path.get_file().get_basename()
		# Cache every component we visit for future lookups
		type_map[global_name] = comp
		if global_name == comp_type:
			_comp_type_cache[eid] = type_map
			return comp

	_comp_type_cache[eid] = type_map
	return null


## Invalidate the component type cache for an entity.
## Call when an entity's components change (add/remove).
func _invalidate_comp_type_cache(entity: Entity) -> void:
	_comp_type_cache.erase(entity.get_instance_id())


## Rebuild the sync entity index entry for an entity.
## Called when components are added/removed or authority changes.
func _update_sync_entity_index(entity: Entity) -> void:
	var eid = entity.get_instance_id()
	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		_sync_entity_index.erase(eid)
		return

	# Collect SyncComponents on this entity
	var sync_comps: Array = []
	for comp in entity.components.values():
		if comp is SyncComponent:
			sync_comps.append(comp)

	if sync_comps.is_empty():
		_sync_entity_index.erase(eid)
	else:
		_sync_entity_index[eid] = {"entity": entity, "sync_comps": sync_comps}


## Remove an entity from the sync entity index.
func _remove_from_sync_entity_index(entity: Entity) -> void:
	_sync_entity_index.erase(entity.get_instance_id())


func _apply_component_data(
	entity: Entity, comp_data: Dictionary, force_overwrite: bool = false
) -> void:
	# Set flag to prevent sync loops when applying received data
	_applying_network_data = true

	for comp_type in comp_data.keys():
		var component = _find_component_by_type(entity, comp_type)
		if not component:
			continue

		var props = comp_data[comp_type]

		# Normal component update - apply directly
		for prop_name in props.keys():
			var value = props[prop_name]

			# Skip if not force_overwrite and value hasn't changed
			if not force_overwrite:
				var current = component.get(prop_name)
				if current == value:
					continue

			# Set property - the _applying_network_data flag prevents
			# property_changed from queueing another sync
			component.set(prop_name, value)

			# For SyncComponents, update cache silently to prevent re-polling same value
			if component is SyncComponent:
				component.update_cache_silent(prop_name, value)

	_applying_network_data = false


# ============================================================================
# PUBLIC API (delegated to handlers)
# ============================================================================


## Transfer authority of an entity to a new peer.
## Only the server can transfer authority.
## @param entity: The entity to transfer
## @param new_owner_peer_id: The new owner's peer ID
func transfer_authority(entity: Entity, new_owner_peer_id: int) -> void:
	_state_handler.transfer_authority(entity, new_owner_peer_id)


## Generate a unique network ID for an entity.
## @param peer_id: The peer ID of the owner
## @param use_deterministic: If true, use counter-based ID (for debugging)
## @return: A unique entity ID string
## @note Requires GECS addon (addons/gecs/io/io.gd) for GECSIO.uuid()
func generate_network_id(peer_id: int, use_deterministic: bool = false) -> String:
	return _state_handler.generate_network_id(peer_id, use_deterministic)


# ============================================================================
# RPC STUBS - All @rpc methods must stay on this Node (Godot requirement).
# Each delegates to the appropriate handler.
# ============================================================================

@rpc("authority", "reliable")
func _sync_world_state(state: Dictionary) -> void:
	_spawn_handler.handle_sync_world_state(state)


@rpc("authority", "reliable")
func _spawn_entity(data: Dictionary) -> void:
	_spawn_handler.handle_spawn_entity(data)


@rpc("authority", "reliable")
func _despawn_entity(entity_id: String, session_id: int = 0) -> void:
	_spawn_handler.handle_despawn_entity(entity_id, session_id)


@rpc("any_peer", "reliable")
func _add_component(
	entity_id: String,
	comp_type: String,
	script_path: String,
	comp_data: Dictionary,
	session_id: int = 0
) -> void:
	_spawn_handler.handle_add_component(entity_id, comp_type, script_path, comp_data, session_id)


## Remove a component from an entity over the network.
## Server broadcasts to all clients, clients send to server for relay.
@rpc("any_peer", "reliable")
func _remove_component(entity_id: String, comp_type: String) -> void:
	_spawn_handler.handle_remove_component(entity_id, comp_type)


## Unreliable RPC for high-frequency updates (position, velocity)
## Packets may be dropped but newer data will replace old
@rpc("any_peer", "unreliable_ordered")
func _sync_components_unreliable(data: Dictionary) -> void:
	_property_handler.handle_apply_sync_data(data)


## Reliable RPC for important state changes (health, inventory)
## Guaranteed delivery, use for data that must not be lost
@rpc("any_peer", "reliable")
func _sync_components_reliable(data: Dictionary) -> void:
	_property_handler.handle_apply_sync_data(data)


## Receive full state reconciliation from server
@rpc("authority", "reliable")
func _sync_full_state(state: Dictionary) -> void:
	_state_handler.handle_sync_full_state(state)


@rpc("authority", "reliable")
func _broadcast_authority_change(entity_id: String, new_owner_peer_id: int) -> void:
	_state_handler.handle_broadcast_authority_change(entity_id, new_owner_peer_id)


@rpc("any_peer", "unreliable")
func _request_server_time(ping_id: int) -> void:
	_state_handler.handle_request_server_time(ping_id)


@rpc("authority", "unreliable")
func _respond_server_time(ping_id: int, server_time: float) -> void:
	_state_handler.handle_respond_server_time(ping_id, server_time)


## Apply position snapshot received from server.
@rpc("authority", "reliable")
func _apply_position_snapshot(positions: Dictionary) -> void:
	_native_handler.handle_apply_position_snapshot(positions)


## RPC to notify all peers to refresh their synchronizer visibility.
## Called by server when a new peer connects.
@rpc("authority", "reliable", "call_local")
func _notify_peers_to_refresh() -> void:
	if debug_logging:
		print("Received refresh notification, updating synchronizer visibility")
	_native_handler.refresh_synchronizer_visibility()


## RPC to sync a relationship addition to other peers.
@rpc("any_peer", "reliable")
func _sync_relationship_add(payload: Dictionary) -> void:
	_relationship_handler.handle_relationship_add(payload)


## RPC to sync a relationship removal to other peers.
@rpc("any_peer", "reliable")
func _sync_relationship_remove(payload: Dictionary) -> void:
	_relationship_handler.handle_relationship_remove(payload)
