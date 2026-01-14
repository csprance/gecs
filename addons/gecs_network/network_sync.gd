class_name NetworkSync
extends Node
## NetworkSync - Attaches to a GECS World to enable multiplayer synchronization.
##
## Add as a child of your World node. Both server and clients use this node -
## behavior differs based on entity authority (C_NetworkIdentity.peer_id).
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
@export var debug_logging: bool = true

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
var _pending_pings: Dictionary = {}  # ping_id -> send_time (for RTT calculation)
var _time_sync_initialized: bool = false

# Entity ID generation
var _spawn_counter: int = 0

# Reconciliation
var _reconciliation_timer: float = 0.0

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
	assert(_world != null, "NetworkSync must be a child of a World node")

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

	# Disconnect from all entities
	for entity in _entity_connections.keys():
		_disconnect_entity_signals(entity)
	_entity_connections.clear()


## Reset NetworkSync state for a new game instance.
## Call this when returning to lobby/menu to ensure clean state for next game.
func reset_for_new_game() -> void:
	if debug_logging:
		print("NetworkSync: Resetting state for new game instance")

	# Clear all pending updates
	for priority in _pending_updates_by_priority.keys():
		_pending_updates_by_priority[priority] = {}

	# Clear pending entity setup queue
	_pending_entity_setup.clear()

	# Reset sync timers
	for priority in _sync_timers.keys():
		_sync_timers[priority] = 0.0

	# Reset time sync (will re-sync when new game starts)
	_time_sync_initialized = false
	_ping_timer = 0.0
	_pending_pings.clear()

	# Reset reconciliation timer
	_reconciliation_timer = 0.0

	# Reset spawn counter for deterministic IDs
	_spawn_counter = 0

	# Disconnect from existing entities (they will be cleaned up)
	for entity in _entity_connections.keys():
		_disconnect_entity_signals(entity)
	_entity_connections.clear()

	if debug_logging:
		print("NetworkSync: State reset complete")


func _process(delta: float) -> void:
	if not net_adapter.is_in_game():
		return

	# Server time synchronization (clients only)
	_sync_server_time(delta)

	# Update sync timers
	_update_sync_timers(delta)

	# Send pending updates (priority-batched)
	_send_pending_updates_batched()

	# Reconciliation (server only)
	_process_reconciliation(delta)


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
	if not net_adapter.is_server():
		return

	if debug_logging:
		print("Peer %d connected, sending world state" % peer_id)

	# Send full world state to new peer
	var state = _serialize_world_state()
	_sync_world_state.rpc_id(peer_id, state)

	# Force existing MultiplayerSynchronizers to update their peer visibility
	# This ensures existing entities sync to the newly connected peer
	_refresh_synchronizer_visibility()

	# Notify all clients to refresh their synchronizers for the new peer
	# This handles the case where client A's synchronizer needs to sync to new client B
	_notify_peers_to_refresh.rpc()

	# Also send current positions via RPC as a failsafe
	# This ensures the reconnecting client gets accurate positions even if native sync delays
	call_deferred("_send_position_snapshot", peer_id)

	# Log sync status for debugging
	call_deferred("_log_sync_status")


func _on_peer_disconnected(peer_id: int) -> void:
	if debug_logging:
		print("Peer %d disconnected" % peer_id)

	if not net_adapter.is_server():
		return

	# Remove entities owned by disconnected peer
	var entities_to_remove: Array[Entity] = []
	for entity in _world.entities:
		var net_id = entity.get_component(C_NetworkIdentity)
		if net_id and net_id.peer_id == peer_id:
			entities_to_remove.append(entity)

	for entity in entities_to_remove:
		if debug_logging:
			print("Removing entity owned by disconnected peer: %s" % entity.id)
		_world.remove_entity(entity)


func _on_connected_to_server() -> void:
	if debug_logging:
		print("Connected to server")

	# Process any pending entities now that we're connected
	_process_pending_entities()

	# Log sync status for debugging (deferred to allow entity setup to complete)
	call_deferred("_log_sync_status")


func _on_connection_failed() -> void:
	if debug_logging:
		print("Connection to server failed")

	# Clear pending entities
	_pending_entity_setup.clear()


func _on_server_disconnected() -> void:
	if debug_logging:
		print("Server disconnected")

	# Clear all networked entities
	var entities_to_remove: Array[Entity] = []
	for entity in _world.entities:
		var net_id = entity.get_component(C_NetworkIdentity)
		if net_id:
			entities_to_remove.append(entity)

	for entity in entities_to_remove:
		_world.remove_entity(entity)


# ============================================================================
# WORLD STATE SYNC (Late Join)
# ============================================================================


func _serialize_world_state() -> Dictionary:
	var entities_data: Array[Dictionary] = []

	for entity in _world.entities:
		var net_id = entity.get_component(C_NetworkIdentity)
		if not net_id:
			continue  # Skip non-networked entities

		entities_data.append(_serialize_entity_spawn(entity))

	return {"entities": entities_data}


@rpc("authority", "reliable")
func _sync_world_state(state: Dictionary) -> void:
	if debug_logging:
		print("Received world state with %d entities" % state.get("entities", []).size())

	var entities_data = state.get("entities", [])
	for entity_data in entities_data:
		_spawn_entity(entity_data)


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
			_auto_assign_markers(entity)
			# Only setup native sync if target_node is explicitly set (model instantiated)
			# Otherwise, _on_component_added will handle it when model_ready_component is added
			var sync_comp = entity.get_component(C_SyncEntity)
			if sync_comp and sync_comp.target_node != null:
				_auto_setup_native_sync(entity)


# ============================================================================
# WORLD SIGNAL HANDLERS
# ============================================================================


func _on_entity_added(entity: Entity) -> void:
	_connect_entity_signals(entity)

	# Check if we should defer setup
	if not _is_ready or not net_adapter.is_in_game():
		if entity.has_component(C_NetworkIdentity):
			if not _pending_entity_setup.has(entity):
				_pending_entity_setup.append(entity)
				if debug_logging:
					print("Queued entity for deferred setup: %s" % entity.id)
		return

	# Auto-assign markers (native sync is deferred until model is instantiated)
	_auto_assign_markers(entity)
	# NOTE: _auto_setup_native_sync is called from _on_component_added when model_ready_component
	# is added, ensuring the sync target exists for proper native sync setup

	# Only server broadcasts spawns
	if not net_adapter.is_server():
		return

	# Check if entity has network identity
	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# IMPORTANT: Defer spawn broadcast to end of frame.
	# This allows component values to be set AFTER add_entity() is called.
	# Without this, spawn RPC would be sent with default component values.
	# Use a pending flag to prevent duplicate broadcasts.
	if not _broadcast_pending.has(entity.id):
		var entity_id = entity.id
		_broadcast_pending[entity_id] = true
		call_deferred("_broadcast_entity_spawn", entity, entity_id)


## Broadcast entity spawn to all clients (called deferred to allow component setup)
func _broadcast_entity_spawn(entity: Entity, entity_id: int) -> void:
	# Validate entity still exists (may have been removed before deferred call)
	if not is_instance_valid(entity):
		_broadcast_pending.erase(entity_id)
		return

	# Clear pending flag (must be done even if we return early)
	_broadcast_pending.erase(entity_id)

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return

	# Serialize and broadcast spawn (now with correct component values)
	var spawn_data = _serialize_entity_spawn(entity)
	if debug_logging:
		print(
			(
				"SERVER: Broadcasting entity spawn: %s (scene: %s)"
				% [entity_id, entity.scene_file_path]
			)
		)
	_spawn_entity.rpc(spawn_data)


func _on_entity_removed(entity: Entity) -> void:
	_disconnect_entity_signals(entity)

	# Remove from pending if queued
	var idx = _pending_entity_setup.find(entity)
	if idx >= 0:
		_pending_entity_setup.remove_at(idx)

	# Only server broadcasts despawns
	if not net_adapter.is_server():
		return

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return

	if debug_logging:
		print("Broadcasting entity despawn: %s" % entity.id)
	_despawn_entity.rpc(entity.id)


func _on_component_added(entity: Entity, component: Resource) -> void:
	# Setup native sync when model_ready_component is added (model ready, sync target exists)
	if sync_config.model_ready_component != "":
		var script = component.get_script()
		if script:
			var comp_name = script.get_global_name()
			if comp_name == sync_config.model_ready_component:
				if entity.has_component(C_SyncEntity):
					_auto_setup_native_sync(entity)
				return  # Don't queue model_ready_component for network sync

	# Queue full component sync when component is added
	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return

	# SPAWN-ONLY SYNC: Skip continuous sync for entities without C_SyncEntity.
	# Their components are only synced at spawn time via _serialize_entity_spawn.
	if not entity.has_component(C_SyncEntity):
		return

	if _should_broadcast(entity, net_id):
		_queue_full_component_sync(entity, component)


func _on_component_removed(entity: Entity, component: Resource) -> void:
	# Skip marker components - they're managed locally
	if component is C_LocalAuthority or component is C_RemoteEntity or component is C_ServerOwned:
		return

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# Only broadcast if we have authority
	if not _should_broadcast(entity, net_id):
		return

	# Get component type name
	var script = component.get_script()
	if script == null:
		return
	var comp_type = script.get_global_name()
	if comp_type == "":
		comp_type = script.resource_path.get_file().get_basename()

	if debug_logging:
		print("Broadcasting component removal: %s from %s" % [comp_type, entity.id])

	# Broadcast removal
	if net_adapter.is_server():
		_remove_component.rpc(entity.id, comp_type)
	else:
		_remove_component.rpc_id(1, entity.id, comp_type)


# ============================================================================
# AUTO-MARKER ASSIGNMENT
# ============================================================================


func _auto_assign_markers(entity: Entity) -> void:
	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# Remove existing marker components to prevent duplicates
	if entity.has_component(C_LocalAuthority):
		entity.remove_component(entity.get_component(C_LocalAuthority))
	if entity.has_component(C_RemoteEntity):
		entity.remove_component(entity.get_component(C_RemoteEntity))
	if entity.has_component(C_ServerOwned):
		entity.remove_component(entity.get_component(C_ServerOwned))

	# Assign markers based on ownership
	if net_id.is_local(net_adapter):
		entity.add_component(C_LocalAuthority.new())
		if debug_logging:
			print("Added C_LocalAuthority to entity: %s" % entity.id)
	else:
		entity.add_component(C_RemoteEntity.new())
		if debug_logging:
			print("Added C_RemoteEntity to entity: %s" % entity.id)

	if net_id.is_server_owned():
		entity.add_component(C_ServerOwned.new())
		if debug_logging:
			print("Added C_ServerOwned to entity: %s" % entity.id)


# ============================================================================
# AUTO-SETUP NATIVE SYNC (MultiplayerSynchronizer)
# ============================================================================


func _auto_setup_native_sync(entity: Entity) -> void:
	var sync_comp = entity.get_component(C_SyncEntity)
	if not sync_comp:
		return  # No sync component, skip native sync setup

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		print("Entity %s has C_SyncEntity but no C_NetworkIdentity" % entity.id)
		return

	var target = sync_comp.get_sync_target(entity)
	if target == null:
		print("C_SyncEntity.get_sync_target() returned null for entity: %s" % entity.id)
		return

	# Check if MultiplayerSynchronizer already exists
	var existing_sync = target.get_node_or_null("_NetSync")
	if existing_sync != null:
		if debug_logging:
			print("MultiplayerSynchronizer already exists for entity: %s" % entity.id)
		return

	# Validate target has required properties
	if not sync_comp.has_sync_properties():
		if debug_logging:
			print("No sync properties configured for entity: %s" % entity.id)
		return

	# Create MultiplayerSynchronizer
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "_NetSync"

	# Configure replication
	var config = SceneReplicationConfig.new()

	# Add properties based on component settings
	var property_paths = sync_comp.get_property_paths(target)
	for prop_path in property_paths:
		# Verify property exists on target
		if prop_path in ["global_position", "global_rotation", "velocity"]:
			# Standard Node3D/CharacterBody3D properties
			config.add_property(":%s" % prop_path)
		elif ":" in prop_path:
			# Child node property path (e.g., "Rig:rotation")
			# Format: ChildNode:property (no leading colon for child paths)
			var parts = prop_path.split(":")
			if parts.size() == 2:
				var child_name = parts[0]
				var child_prop = parts[1]
				var child_node = target.get_node_or_null(child_name)
				if child_node and child_prop in child_node:
					config.add_property("%s:%s" % [child_name, child_prop])
				else:
					print(
						(
							"Child property '%s' not found on target for entity: %s"
							% [prop_path, entity.id]
						)
					)
			else:
				print("Invalid property path format '%s' for entity: %s" % [prop_path, entity.id])
		else:
			# Custom property on target node - check if exists
			if prop_path in target:
				config.add_property(":%s" % prop_path)
			else:
				print("Property '%s' not found on target for entity: %s" % [prop_path, entity.id])

	# Apply configuration
	synchronizer.replication_config = config

	# Configure advanced options
	synchronizer.visibility_update_mode = sync_comp.visibility_mode
	synchronizer.delta_interval = sync_comp.delta_interval
	synchronizer.replication_interval = sync_comp.replication_interval
	synchronizer.public_visibility = sync_comp.public_visibility

	# Add to target node
	target.add_child(synchronizer)

	# Set multiplayer authority
	synchronizer.set_multiplayer_authority(net_id.peer_id if net_id.peer_id > 0 else 1)

	if debug_logging:
		var target_path = target.get_path() if target else "null"
		print("Created MultiplayerSynchronizer for entity: %s" % entity.id)
		print(
			"  -> target=%s, authority=%d, props=%s" % [target_path, net_id.peer_id, property_paths]
		)


## Log current sync status for all entities with C_SyncEntity.
## Useful for debugging sync issues after peer connects.
func _log_sync_status() -> void:
	if not debug_logging:
		return

	var sync_entities: Array = []
	for entity in _world.entities:
		if entity.has_component(C_SyncEntity):
			sync_entities.append(entity)

	if sync_entities.is_empty():
		print("Sync status: No entities with C_SyncEntity")
		return

	var prefix = "SERVER" if net_adapter.is_server() else "CLIENT"
	print("%s: Sync status - %d entities with C_SyncEntity" % [prefix, sync_entities.size()])

	for entity in sync_entities:
		var sync_comp = entity.get_component(C_SyncEntity)
		var net_id = entity.get_component(C_NetworkIdentity)
		var target = sync_comp.get_sync_target(entity)

		var status_parts: Array = []

		# Check MultiplayerSynchronizer
		var synchronizer: MultiplayerSynchronizer = null
		if target:
			synchronizer = target.get_node_or_null("_NetSync") as MultiplayerSynchronizer

		if synchronizer:
			var authority = synchronizer.get_multiplayer_authority()
			var is_local = net_id and net_id.is_local(net_adapter)
			status_parts.append("sync=OK")
			status_parts.append("auth=%d" % authority)
			status_parts.append("local=%s" % is_local)
			if synchronizer.replication_config:
				var prop_count = synchronizer.replication_config.get_properties().size()
				status_parts.append("props=%d" % prop_count)
		else:
			status_parts.append("sync=MISSING")

		# Target node info
		if target:
			status_parts.append("target=%s" % target.name)
		else:
			status_parts.append("target=null")

		print("  -> %s: %s" % [entity.id, ", ".join(status_parts)])


# ============================================================================
# ENTITY SIGNAL MANAGEMENT
# ============================================================================


func _connect_entity_signals(entity: Entity) -> void:
	if _entity_connections.has(entity):
		return  # Already connected

	var callback = func(ent: Entity, comp: Resource, prop: String, old_val, new_val):
		_on_component_property_changed(ent, comp, prop, old_val, new_val)

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
# PROPERTY CHANGE HANDLER
# ============================================================================


func _on_component_property_changed(
	entity: Entity, component: Resource, property: String, _old_value, new_value
) -> void:
	# Skip if we're applying network data - prevents sync loops
	if _applying_network_data:
		return

	# Check if this component should be skipped (C_Transform handled by native sync)
	if sync_config and sync_config.should_skip_component(component):
		return

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# SPAWN-ONLY SYNC: Entities without C_SyncEntity only sync at spawn time.
	# Skip continuous property sync for these entities (e.g., projectiles).
	# This allows local deterministic simulation without network interference.
	if not entity.has_component(C_SyncEntity):
		return

	if _should_broadcast(entity, net_id):
		_queue_component_update(entity, component, property, new_value)

		# Log HIGH priority component changes for debugging sync flow
		if debug_logging:
			var comp_type = component.get_script().get_global_name()
			var priority = (
				sync_config.get_priority(component) if sync_config else SyncConfig.Priority.MEDIUM
			)
			if priority == SyncConfig.Priority.HIGH:
				var prefix = "SERVER" if net_adapter.is_server() else "CLIENT"
				print(
					(
						"%s: Property change queued: entity=%s, comp=%s, prop=%s"
						% [prefix, entity.id, comp_type, property]
					)
				)


func _should_broadcast(_entity: Entity, net_id: C_NetworkIdentity) -> bool:
	# Server broadcasts ALL changes
	if net_adapter.is_server():
		return true

	# Client only broadcasts for entities they own (local player)
	return net_id.peer_id == net_adapter.get_my_peer_id()


# ============================================================================
# UPDATE QUEUING
# ============================================================================


func _queue_component_update(
	entity: Entity, component: Resource, property: String, value: Variant
) -> void:
	var entity_id = entity.id
	var comp_type = component.get_script().get_global_name()

	# Get priority for this component type
	var priority = (
		sync_config.get_priority(component) if sync_config else SyncConfig.Priority.MEDIUM
	)

	# Ensure priority batch exists
	if not _pending_updates_by_priority.has(priority):
		_pending_updates_by_priority[priority] = {}
	if not _pending_updates_by_priority[priority].has(entity_id):
		_pending_updates_by_priority[priority][entity_id] = {}
	if not _pending_updates_by_priority[priority][entity_id].has(comp_type):
		_pending_updates_by_priority[priority][entity_id][comp_type] = {}

	# For transform component, always send both position and rotation together
	# This ensures rotation-only updates don't get filtered out on the receiving end
	if sync_config.transform_component != "" and comp_type == sync_config.transform_component:
		# Use generic property access since component class name is configurable
		if "position" in component and "rotation" in component:
			_pending_updates_by_priority[priority][entity_id][comp_type]["position"] = (
				component.get("position")
			)
			_pending_updates_by_priority[priority][entity_id][comp_type]["rotation"] = (
				component.get("rotation")
			)
		else:
			# Fallback if properties don't exist
			_pending_updates_by_priority[priority][entity_id][comp_type][property] = value
	else:
		_pending_updates_by_priority[priority][entity_id][comp_type][property] = value


func _queue_full_component_sync(entity: Entity, component: Resource) -> void:
	var entity_id = entity.id
	var comp_type = component.get_script().get_global_name()
	var data = component.serialize()

	# Get priority for this component type
	var priority = (
		sync_config.get_priority(component) if sync_config else SyncConfig.Priority.MEDIUM
	)

	if not _pending_updates_by_priority.has(priority):
		_pending_updates_by_priority[priority] = {}
	if not _pending_updates_by_priority[priority].has(entity_id):
		_pending_updates_by_priority[priority][entity_id] = {}

	_pending_updates_by_priority[priority][entity_id][comp_type] = data


## Queue received client data for relay to other clients (server only)
## This ensures rotation-only updates get relayed when player is stationary
func _queue_relay_data(entity_id: String, comp_data: Dictionary) -> void:
	# Relay data uses HIGH priority for responsiveness
	var priority = SyncConfig.Priority.HIGH

	if not _pending_updates_by_priority.has(priority):
		_pending_updates_by_priority[priority] = {}
	if not _pending_updates_by_priority[priority].has(entity_id):
		_pending_updates_by_priority[priority][entity_id] = {}

	# Merge received component data into pending updates
	for comp_type in comp_data.keys():
		if not _pending_updates_by_priority[priority][entity_id].has(comp_type):
			_pending_updates_by_priority[priority][entity_id][comp_type] = {}

		# Merge properties (received data takes priority for relay)
		for prop_name in comp_data[comp_type].keys():
			_pending_updates_by_priority[priority][entity_id][comp_type][prop_name] = (comp_data[comp_type][prop_name])


# ============================================================================
# SYNC TIMERS & SENDING
# ============================================================================


func _update_sync_timers(delta: float) -> void:
	for priority in _sync_timers.keys():
		_sync_timers[priority] += delta


func _send_pending_updates_batched() -> void:
	# Send updates for each priority level when its interval has elapsed
	for priority in SyncConfig.Priority.values():
		if not SyncConfig.should_sync(priority, _sync_timers[priority]):
			continue

		# Reset timer for this priority
		_sync_timers[priority] = 0.0

		# Poll SyncComponents for changes at this priority level
		_poll_sync_components_for_priority(priority)

		# Get pending updates for this priority
		if not _pending_updates_by_priority.has(priority):
			continue
		var batch = _pending_updates_by_priority[priority]
		if batch.is_empty():
			continue

		# Clear the batch before sending (prevents double-send)
		_pending_updates_by_priority[priority] = {}

		# Log batch send details for debugging sync flow
		if debug_logging:
			var entity_count = batch.size()
			var prop_count = 0
			for entity_id in batch.keys():
				for comp_type in batch[entity_id].keys():
					prop_count += batch[entity_id][comp_type].size()
			var priority_name = SyncConfig.Priority.keys()[priority]
			var prefix = "SERVER" if net_adapter.is_server() else "CLIENT"
			print(
				(
					"%s: Batch send: priority=%s, entities=%d, properties=%d"
					% [prefix, priority_name, entity_count, prop_count]
				)
			)

		# Choose RPC method based on reliability
		var reliability = SyncConfig.get_reliability(priority)

		# Server sends to all clients
		if net_adapter.is_server():
			if reliability == SyncConfig.Reliability.UNRELIABLE:
				_sync_components_unreliable.rpc(batch)
			else:
				_sync_components_reliable.rpc(batch)
		else:
			# Client sends to server only (for owned entities)
			if reliability == SyncConfig.Reliability.UNRELIABLE:
				_sync_components_unreliable.rpc_id(1, batch)
			else:
				_sync_components_reliable.rpc_id(1, batch)


## Poll all SyncComponents for changes at a specific priority level.
## This triggers property_changed signals for any detected changes,
## which then get queued via _on_component_property_changed().
func _poll_sync_components_for_priority(priority: int) -> void:
	for entity in _world.entities:
		var net_id = entity.get_component(C_NetworkIdentity)
		if not net_id:
			continue

		# Only broadcast changes for entities we have authority over
		if not _should_broadcast(entity, net_id):
			continue

		# Poll all SyncComponents on this entity
		for comp in entity.components.values():
			if comp is SyncComponent:
				comp.check_changes_for_priority(priority)


# ============================================================================
# RPC - COMPONENT SYNC
# ============================================================================

## Unreliable RPC for high-frequency updates (position, velocity)
## Packets may be dropped but newer data will replace old
@rpc("any_peer", "unreliable_ordered")
func _sync_components_unreliable(data: Dictionary) -> void:
	_apply_sync_data(data)


## Reliable RPC for important state changes (health, inventory)
## Guaranteed delivery, use for data that must not be lost
@rpc("any_peer", "reliable")
func _sync_components_reliable(data: Dictionary) -> void:
	_apply_sync_data(data)


## Shared handler for both reliable and unreliable syncs
func _apply_sync_data(data: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	var prefix = "SERVER" if net_adapter.is_server() else "CLIENT"

	# Log incoming sync data at DEBUG level
	if debug_logging:
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
		var entity = _world.entity_id_registry.get(entity_id)
		if not entity:
			if debug_logging:
				print("Received update for unknown entity: %s" % entity_id)
			continue

		var net_id = entity.get_component(C_NetworkIdentity)
		if not net_id:
			continue

		# SPAWN-ONLY SYNC: Skip continuous updates for entities without C_SyncEntity.
		# These entities (e.g., projectiles) only sync at spawn time.
		if not entity.has_component(C_SyncEntity):
			if debug_logging:
				print("Skipping sync data for spawn-only entity: %s" % entity_id)
			continue

		# Validation: Only accept updates from authorized sources
		if net_adapter.is_server():
			# Server accepts updates from entity owner only
			if net_id.peer_id != sender_id:
				if debug_logging:
					print(
						(
							"Rejected update from peer %d for entity owned by peer %d"
							% [sender_id, net_id.peer_id]
						)
					)
				continue

			# SERVER RELAY: Queue received client data for broadcast to OTHER clients
			# This ensures rotation-only updates (when stationary) get relayed
			# The sending client will filter out their own entity when receiving
			_queue_relay_data(entity_id, data[entity_id])
		else:
			# Clients accept updates from server (peer 1) only
			if sender_id != 1:
				if debug_logging:
					print("Rejected update from non-server peer %d" % sender_id)
				continue

			# CRITICAL: Clients should NOT accept updates for entities they OWN
			# The client is authoritative for their own player's movement/input
			# Server only relays updates for OTHER players' entities
			if net_id.is_local(net_adapter):
				if debug_logging:
					print("Skipping server update for locally-owned entity: %s" % entity_id)
				continue

		# Apply component data
		_apply_component_data(entity, data[entity_id])

		# Log applied component data at DEBUG level
		if debug_logging:
			var applied_comps: Array[String] = []
			for comp_type in data[entity_id].keys():
				applied_comps.append(comp_type)
			print(
				(
					"%s: Applied sync data to entity=%s: components=%s"
					% [prefix, entity_id, applied_comps]
				)
			)


# ============================================================================
# RPC - ENTITY SPAWN/DESPAWN
# ============================================================================

@rpc("authority", "reliable")
func _spawn_entity(data: Dictionary) -> void:
	var entity_id = data.get("id", "")
	var scene_path = data.get("scene_path", "")

	if debug_logging:
		print("CLIENT: Received entity spawn RPC: %s (scene: %s)" % [entity_id, scene_path])

	if entity_id == "":
		print("Received spawn with empty entity ID")
		return

	# Validate scene path
	if scene_path != "" and not _validate_entity_spawn(scene_path):
		return

	# Check if entity already exists
	if _world.entity_id_registry.has(entity_id):
		if debug_logging:
			print("Entity already exists, updating: %s" % entity_id)
		var existing = _world.entity_id_registry[entity_id]
		_apply_component_data(existing, data.get("components", {}))
		return

	# Instantiate entity from scene path
	var entity: Entity

	if scene_path != "":
		var scene = load(scene_path)
		if scene:
			entity = scene.instantiate()
		else:
			print("Failed to load scene: %s" % scene_path)
			return
	else:
		entity = Entity.new()

	entity.id = entity_id

	# For player entities, extract peer_id from serialized C_NetworkIdentity
	# and set up multiplayer authority BEFORE adding to world
	var components_data = data.get("components", {})
	var peer_id_for_name = 0
	if components_data.has("C_NetworkIdentity"):
		var net_id_data = components_data["C_NetworkIdentity"]
		var peer_id = net_id_data.get("peer_id", 0)
		if peer_id > 0:
			peer_id_for_name = peer_id
			# Set multiplayer authority for this entity
			entity.set_multiplayer_authority(peer_id)
			# For E_Player, also set owner_peer_id so on_ready() creates C_NetworkIdentity correctly
			if "owner_peer_id" in entity:
				entity.set("owner_peer_id", peer_id)
			if debug_logging:
				print("Set multiplayer authority to %d for entity %s" % [peer_id, entity_id])

	# Set entity name - for players, use peer_id so _enter_tree() parses it correctly
	# For other entities, use entity_id
	entity.name = str(peer_id_for_name) if peer_id_for_name > 0 else entity_id

	# Add to world (World.add_entity adds to scene tree via entity_nodes_root)
	# This triggers _initialize() -> define_components() -> on_ready()
	_world.add_entity(entity)

	# Apply initial component data AFTER define_components has run
	# This updates the components with server's authoritative values
	_apply_component_data(entity, components_data)

	# Sync Node3D position from transform component to prevent spawning at origin.
	# This is critical for spawn-only entities (projectiles) that don't use C_SyncEntity.
	if entity is Entity and sync_config.transform_component != "":
		var transform_comp = _find_component_by_type(entity, sync_config.transform_component)
		if transform_comp and "position" in transform_comp:
			entity.global_position = transform_comp.get("position")

	# Note: _auto_assign_markers and _auto_setup_native_sync are called
	# automatically via _on_entity_added signal handler

	# Emit signal for projects to do post-spawn setup (e.g., apply visual properties)
	entity_spawned.emit(entity)

	if debug_logging:
		print(
			(
				"CLIENT: Entity spawned successfully: %s (components: %d)"
				% [entity_id, components_data.size()]
			)
		)

	# Check if this is the local player and emit signal for UI setup
	var net_id = entity.get_component(C_NetworkIdentity) as C_NetworkIdentity
	if net_id and net_id.is_local(net_adapter):
		if debug_logging:
			print(
				(
					"CLIENT: Local player entity spawned: %s (peer_id: %d)"
					% [entity_id, net_id.peer_id]
				)
			)
		local_player_spawned.emit(entity)
	elif net_id:
		if debug_logging:
			print(
				(
					"CLIENT: Remote player entity spawned: %s (owner peer_id: %d)"
					% [entity_id, net_id.peer_id]
				)
			)


@rpc("authority", "reliable")
func _despawn_entity(entity_id: String) -> void:
	var entity = _world.entity_id_registry.get(entity_id)
	if entity:
		_world.remove_entity(entity)
		if debug_logging:
			print("Despawned entity: %s" % entity_id)


## Remove a component from an entity over the network.
## Server broadcasts to all clients, clients send to server for relay.
@rpc("any_peer", "reliable")
func _remove_component(entity_id: String, comp_type: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()

	var entity = _world.entity_id_registry.get(entity_id)
	if not entity:
		if debug_logging:
			print("Received component removal for unknown entity: %s" % entity_id)
		return

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		return

	# Validation: Only accept from authorized sources
	if net_adapter.is_server():
		# Server accepts from entity owner only
		if net_id.peer_id != sender_id:
			if debug_logging:
				print(
					(
						"Rejected component removal from peer %d for entity owned by peer %d"
						% [sender_id, net_id.peer_id]
					)
				)
			return
		# Relay to all clients
		_remove_component.rpc(entity_id, comp_type)
	else:
		# Client accepts from server only
		if sender_id != 1:
			if debug_logging:
				print("Rejected component removal from non-server peer %d" % sender_id)
			return
		# Skip if this is our own entity
		if net_id.is_local(net_adapter):
			return

	# Find and remove the component
	var component = _find_component_by_type(entity, comp_type)
	if component:
		# Set flag to prevent sync loops
		_applying_network_data = true
		entity.remove_component(component)
		_applying_network_data = false
		if debug_logging:
			print("Removed component %s from entity %s" % [comp_type, entity_id])


# ============================================================================
# VALIDATION & ERROR HANDLING
# ============================================================================


func _validate_entity_spawn(scene_path: String) -> bool:
	# Empty scene path means Entity.new() - always allowed
	if scene_path == "":
		return true

	# Check if scene exists
	if not ResourceLoader.exists(scene_path):
		print("Invalid scene path for spawn: %s" % scene_path)
		return false

	return true


# ============================================================================
# SERIALIZATION HELPERS
# ============================================================================


func _serialize_entity_spawn(entity: Entity) -> Dictionary:
	var components_data = {}

	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		var comp_type = comp.get_script().get_global_name()
		components_data[comp_type] = comp.serialize()

	return {"id": entity.id, "scene_path": entity.scene_file_path, "components": components_data}


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


func _find_component_by_type(entity: Entity, comp_type: String) -> Component:
	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		var script = comp.get_script()
		if script == null:
			continue
		var global_name = script.get_global_name()
		# Fallback to filename if class_name not declared
		if global_name == "":
			global_name = script.resource_path.get_file().get_basename()
		if global_name == comp_type:
			return comp
	return null


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
		_spawn_counter += 1
		var timestamp = Time.get_ticks_msec()
		return "%d_%d_%d" % [peer_id, timestamp, _spawn_counter]

	# Requires GECS addon: addons/gecs/io/io.gd
	return GECSIO.uuid()


# ============================================================================
# SERVER TIME SYNCHRONIZATION
# ============================================================================


## Sync client's clock with server time (clients only)
func _sync_server_time(delta: float) -> void:
	if net_adapter.is_server():
		return  # Server is the time authority

	_ping_timer += delta

	# Initial sync or periodic re-sync
	if not _time_sync_initialized or _ping_timer >= _ping_interval:
		_ping_timer = 0.0
		_send_time_ping()


func _send_time_ping() -> void:
	var ping_id = randi()
	var send_time = Time.get_ticks_msec() / 1000.0
	_pending_pings[ping_id] = send_time
	_request_server_time.rpc_id(1, ping_id)

	if debug_logging:
		print("Sent time ping %d" % ping_id)


@rpc("any_peer", "unreliable")
func _request_server_time(ping_id: int) -> void:
	if not net_adapter.is_server():
		return
	var server_time = Time.get_ticks_msec() / 1000.0
	_respond_server_time.rpc_id(multiplayer.get_remote_sender_id(), ping_id, server_time)


@rpc("authority", "unreliable")
func _respond_server_time(ping_id: int, server_time: float) -> void:
	if not _pending_pings.has(ping_id):
		return

	var send_time = _pending_pings[ping_id]
	_pending_pings.erase(ping_id)

	var receive_time = Time.get_ticks_msec() / 1000.0
	var rtt = receive_time - send_time

	# Estimate server time at receive moment (server_time + half RTT)
	var estimated_server_now = server_time + (rtt / 2.0)
	_server_time_offset = estimated_server_now - receive_time

	_time_sync_initialized = true

	if debug_logging:
		print("Time sync: offset=%.3fs, RTT=%.1fms" % [_server_time_offset, rtt * 1000])


# ============================================================================
# RECONCILIATION (Periodic Full State Sync)
# ============================================================================


## Process reconciliation timer (server only)
func _process_reconciliation(delta: float) -> void:
	if not net_adapter.is_server():
		return

	if not sync_config or not sync_config.enable_reconciliation:
		return

	_reconciliation_timer += delta

	if _reconciliation_timer >= sync_config.reconciliation_interval:
		_reconciliation_timer = 0.0
		_broadcast_full_state()


## Broadcast full state of all networked entities to all clients
func _broadcast_full_state() -> void:
	if not net_adapter.is_server():
		return

	var full_state: Dictionary = {}

	for entity in _world.entities:
		var net_id = entity.get_component(C_NetworkIdentity)
		if not net_id:
			continue

		full_state[entity.id] = _serialize_entity_full(entity)

	if full_state.is_empty():
		return

	if debug_logging:
		print("Broadcasting full state reconciliation (%d entities)" % full_state.size())

	_sync_full_state.rpc(full_state)


## Serialize all component data for an entity
func _serialize_entity_full(entity: Entity) -> Dictionary:
	var components_data: Dictionary = {}

	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		var comp_type = comp.get_script().get_global_name()

		# Skip components that should be filtered
		if sync_config and sync_config.should_skip(comp_type):
			continue

		components_data[comp_type] = comp.serialize()

	return components_data


## Receive full state reconciliation from server
@rpc("authority", "reliable")
func _sync_full_state(state: Dictionary) -> void:
	if debug_logging:
		print("Received full state reconciliation (%d entities)" % state.size())

	for entity_id in state.keys():
		var entity = _world.entity_id_registry.get(entity_id)
		if not entity:
			if debug_logging:
				print("Reconciliation: unknown entity %s" % entity_id)
			continue

		var net_id = entity.get_component(C_NetworkIdentity)
		if not net_id:
			continue

		# Skip local entities - we're authoritative for our own data
		if net_id.is_local(net_adapter):
			continue

		# Apply full state with force_overwrite to correct any drift
		_apply_component_data(entity, state[entity_id], true)


# ============================================================================
# AUTHORITY TRANSFER
# ============================================================================


## Transfer authority of an entity to a new peer.
## Only the server can transfer authority.
## @param entity: The entity to transfer
## @param new_owner_peer_id: The new owner's peer ID
func transfer_authority(entity: Entity, new_owner_peer_id: int) -> void:
	if not net_adapter.is_server():
		print("Only server can transfer authority")
		return

	var net_id = entity.get_component(C_NetworkIdentity)
	if not net_id:
		print("Cannot transfer authority: entity has no C_NetworkIdentity")
		return

	if not _is_valid_peer(new_owner_peer_id):
		print("Invalid peer ID for authority transfer: %d" % new_owner_peer_id)
		return

	var old_owner = net_id.peer_id

	# Update peer_id
	net_id.peer_id = new_owner_peer_id

	# Reassign markers
	_auto_assign_markers(entity)

	# Update MultiplayerSynchronizer authority if present
	var sync_comp = entity.get_component(C_SyncEntity)
	if sync_comp:
		var target = sync_comp.get_sync_target(entity)
		if target:
			var synchronizer = target.get_node_or_null("_NetSync")
			if synchronizer:
				synchronizer.set_multiplayer_authority(
					new_owner_peer_id if new_owner_peer_id > 0 else 1
				)

	# Broadcast authority change to all clients
	_broadcast_authority_change.rpc(entity.id, new_owner_peer_id)

	if debug_logging:
		print(
			(
				"Transferred authority of %s from peer %d to peer %d"
				% [entity.id, old_owner, new_owner_peer_id]
			)
		)


@rpc("authority", "reliable")
func _broadcast_authority_change(entity_id: String, new_owner_peer_id: int) -> void:
	var entity = _world.entity_id_registry.get(entity_id)
	if not entity:
		return

	var net_id = entity.get_component(C_NetworkIdentity)
	if net_id:
		net_id.peer_id = new_owner_peer_id
		_auto_assign_markers(entity)

		# Update synchronizer authority
		var sync_comp = entity.get_component(C_SyncEntity)
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
	var peers = net_adapter.get_connected_peers()
	return peer_id in peers or peer_id == net_adapter.get_my_peer_id()


# ============================================================================
# SYNCHRONIZER VISIBILITY REFRESH
# ============================================================================


## Send current position snapshot to a specific peer.
## Called deferred after world state to ensure entity setup is complete.
func _send_position_snapshot(peer_id: int) -> void:
	var positions: Dictionary = {}

	for entity in _world.entities:
		var net_id = entity.get_component(C_NetworkIdentity)
		if not net_id:
			continue

		if sync_config.transform_component == "":
			continue  # Transform component not configured

		var transform_comp = _find_component_by_type(entity, sync_config.transform_component)
		if not transform_comp:
			continue

		# Also get position from CharacterBody3D if available (more accurate)
		var sync_comp = entity.get_component(C_SyncEntity)
		var pos = transform_comp.get("position") if "position" in transform_comp else Vector3.ZERO
		var rot = transform_comp.get("rotation") if "rotation" in transform_comp else Vector3.ZERO

		if sync_comp and sync_comp.target_node:
			var target = sync_comp.target_node
			if "global_position" in target:
				pos = target.global_position
			# Get Rig rotation if available
			# NOTE: Assumes target has a 'Rig' child node (see docs above _apply_position_snapshot)
			var rig = target.get_node_or_null("Rig")
			if rig and "rotation" in rig:
				rot = rig.rotation

		positions[entity.id] = {"position": pos, "rotation": rot}

	if not positions.is_empty():
		if debug_logging:
			print(
				"Sending position snapshot to peer %d (%d entities)" % [peer_id, positions.size()]
			)
		_apply_position_snapshot.rpc_id(peer_id, positions)


## NOTE: Rotation Source Assumption
## This code assumes entities have a 'Rig' child node that contains the rotation data.
## This is specific to projects using a particular node hierarchy structure.
##
## If your project uses a different hierarchy:
## - Option 1: Rename your rotation node to 'Rig'
## - Option 2: Modify the get_node_or_null("Rig") calls to match your hierarchy
## - Option 3: Make this configurable (see TODO below)
##
## Example alternative hierarchies:
##   - direct_rotation: target.rotation instead of target.get_node_or_null("Rig").rotation
##   - model_node: target.get_node_or_null("Model").rotation
##   - animated_sprite: target.get_node_or_null("AnimatedSprite3D").rotation
##
## TODO: Make rotation source configurable via sync_config (e.g., rotation_node_path: "Rig")

## Apply position snapshot received from server.
@rpc("authority", "reliable")
func _apply_position_snapshot(positions: Dictionary) -> void:
	if debug_logging:
		print("Received position snapshot with %d entities" % positions.size())

	for entity_id in positions.keys():
		var entity = _world.entity_id_registry.get(entity_id)
		if not entity:
			continue

		var data = positions[entity_id]
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		var rot: Vector3 = data.get("rotation", Vector3.ZERO)

		# Update transform component
		if sync_config.transform_component != "":
			var transform_comp = _find_component_by_type(entity, sync_config.transform_component)
			if transform_comp:
				if "position" in transform_comp:
					transform_comp.set("position", pos)
				if "rotation" in transform_comp:
					transform_comp.set("rotation", rot)

		# Also update CharacterBody3D directly if available
		var sync_comp = entity.get_component(C_SyncEntity)
		if sync_comp and sync_comp.target_node:
			var target = sync_comp.target_node
			if "global_position" in target:
				target.global_position = pos
			# Apply rotation to Rig child node
			# NOTE: Assumes target has a 'Rig' child node (see docs above this function)
			var rig = target.get_node_or_null("Rig")
			if rig and "rotation" in rig:
				rig.rotation = rot


## RPC to notify all peers to refresh their synchronizer visibility.
## Called by server when a new peer connects.
@rpc("authority", "reliable", "call_local")
func _notify_peers_to_refresh() -> void:
	if debug_logging:
		print("Received refresh notification, updating synchronizer visibility")
	_refresh_synchronizer_visibility()


## Refresh visibility for all existing MultiplayerSynchronizers.
## Called when a new peer connects to ensure they receive updates from existing entities.
## This forces synchronizers to update their peer visibility lists.
func _refresh_synchronizer_visibility() -> void:
	var refreshed_count = 0
	var missing_sync_count = 0

	for entity in _world.entities:
		var sync_comp = entity.get_component(C_SyncEntity)
		if not sync_comp:
			continue

		var target = sync_comp.get_sync_target(entity)
		if not target:
			continue

		var synchronizer = target.get_node_or_null("_NetSync") as MultiplayerSynchronizer
		if not synchronizer:
			missing_sync_count += 1
			if debug_logging:
				print("Entity %s has C_SyncEntity but no MultiplayerSynchronizer yet" % entity.id)
			continue

		# Force visibility update by toggling public_visibility
		# This triggers Godot to rebuild the peer visibility list
		var was_public = synchronizer.public_visibility
		synchronizer.public_visibility = false
		synchronizer.public_visibility = was_public
		refreshed_count += 1

		if debug_logging:
			print(
				(
					"Refreshed visibility for entity: %s (authority=%d)"
					% [entity.id, synchronizer.get_multiplayer_authority()]
				)
			)

	if debug_logging:
		var prefix = "SERVER" if net_adapter.is_server() else "CLIENT"
		print(
			(
				"%s: Refreshed %d synchronizers (%d entities without sync)"
				% [prefix, refreshed_count, missing_sync_count]
			)
		)
