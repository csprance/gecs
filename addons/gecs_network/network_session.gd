class_name NetworkSession
extends Node
## High-level multiplayer session manager.
## Wraps ENet host/join boilerplate into a declarative Node with ECS-friendly events.
##
## Usage:
##   var session = NetworkSession.new()
##   session.transport = ENetTransportProvider.new()
##   add_child(session)
##   session.host()   # or session.join("127.0.0.1")

# ---------------------------------------------------------------------------
# Exported configuration
# ---------------------------------------------------------------------------

@export var transport: TransportProvider
@export var max_players: int = 4
@export var default_port: int = 7777
@export var debug_logging: bool = false
@export var auto_start_network_sync: bool = true

# ---------------------------------------------------------------------------
# Callable hooks (optional, default to no-op)
# ---------------------------------------------------------------------------

var on_before_host: Callable = Callable()
var on_host_success: Callable = Callable()
var on_before_join: Callable = Callable()
var on_join_success: Callable = Callable()
var on_peer_connected: Callable = Callable()
var on_peer_disconnected: Callable = Callable()
var on_session_ended: Callable = Callable()

# ---------------------------------------------------------------------------
# Read-only access to internal NetworkSync (null until host/join)
# ---------------------------------------------------------------------------

var network_sync: NetworkSync :
	get:
		return _network_sync

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _network_sync: NetworkSync
var _session_entity: Entity
var _signals_connected: bool = false
var _state: CN_SessionState

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if transport == null:
		transport = ENetTransportProvider.new()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start hosting a session. Uses default_port if port == -1.
## Returns OK on success, or ERR_CANT_CONNECT if transport returns null.
func host(port: int = -1) -> Error:
	if port == -1:
		port = default_port

	if on_before_host.is_valid():
		on_before_host.call()

	var config: Dictionary = {
		"port": port,
		"max_players": max_players,
		"bind_address": "0.0.0.0"
	}
	var peer = transport.create_host_peer(config)
	if peer == null:
		return ERR_CANT_CONNECT

	multiplayer.multiplayer_peer = peer
	_connect_multiplayer_signals()

	if auto_start_network_sync:
		var world = _get_world()
		if world != null:
			_network_sync = NetworkSync.attach_to_world(world)
			_network_sync.debug_logging = debug_logging

	# Plan 03 will add CN_SessionStarted and update CN_SessionState here.

	if on_host_success.is_valid():
		on_host_success.call()

	return OK


## Join an existing session at ip:port. Uses default_port if port == -1.
## Returns OK on success, or ERR_CANT_CONNECT if transport returns null.
func join(ip: String, port: int = -1) -> Error:
	if port == -1:
		port = default_port

	if on_before_join.is_valid():
		on_before_join.call()

	var config: Dictionary = {"address": ip, "port": port}
	var peer = transport.create_client_peer(config)
	if peer == null:
		return ERR_CANT_CONNECT

	multiplayer.multiplayer_peer = peer
	_connect_multiplayer_signals()

	if auto_start_network_sync:
		var world = _get_world()
		if world != null:
			_network_sync = NetworkSync.attach_to_world(world)
			_network_sync.debug_logging = debug_logging

	# on_join_success fires in _on_connected_to_server — must wait for
	# server confirmation before declaring the join successful.

	return OK


## End the active session and clean up all network resources.
## Order per Pattern 5: hook -> entities -> signals -> sync -> peer -> reset.
func end_session() -> void:
	# 1. Fire the hook first so callers can react before teardown.
	if on_session_ended.is_valid():
		on_session_ended.call()

	# Plan 03 will fire CN_SessionEnded component event here.

	# 2. Remove all networked entities from the world so despawn RPCs
	#    can still fire before the peer is nulled.
	var world = _get_world()
	if world != null and is_instance_valid(world):
		var to_remove = world.entities.duplicate()
		for entity in to_remove:
			if is_instance_valid(entity):
				world.remove_entity(entity)
				entity.queue_free()

	# 3. Disconnect multiplayer signals to prevent stale callbacks.
	_disconnect_multiplayer_signals()

	# 4. Free the NetworkSync node (disconnects world signals internally).
	if _network_sync != null and is_instance_valid(_network_sync):
		_network_sync.queue_free()
		_network_sync = null

	# 5. Null the peer — this triggers server_disconnected on clients.
	multiplayer.multiplayer_peer = null

	# 6. Plan 03 will reset CN_SessionState here.
	_session_entity = null
	_state = null


# ---------------------------------------------------------------------------
# Internal signal wiring
# ---------------------------------------------------------------------------

func _connect_multiplayer_signals() -> void:
	if _signals_connected:
		return
	multiplayer.peer_connected.connect(_on_peer_connected_signal)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected_signal)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_signals_connected = true


func _disconnect_multiplayer_signals() -> void:
	if not _signals_connected:
		return
	if multiplayer.peer_connected.is_connected(_on_peer_connected_signal):
		multiplayer.peer_connected.disconnect(_on_peer_connected_signal)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected_signal):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected_signal)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	_signals_connected = false


func _on_peer_connected_signal(peer_id: int) -> void:
	# Plan 03 will add CN_PeerJoined component to the session entity here.
	if on_peer_connected.is_valid():
		on_peer_connected.call(peer_id)


func _on_peer_disconnected_signal(peer_id: int) -> void:
	# Plan 03 will add CN_PeerLeft component to the session entity here.
	if on_peer_disconnected.is_valid():
		on_peer_disconnected.call(peer_id)


func _on_connected_to_server() -> void:
	# Plan 03 will add CN_SessionStarted component here.
	if on_join_success.is_valid():
		on_join_success.call()


func _on_connection_failed() -> void:
	end_session()


func _on_server_disconnected() -> void:
	end_session()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _update_session_state(connected: bool, hosting: bool, peer_count: int) -> void:
	if _state == null:
		return
	_state.is_connected = connected
	_state.is_hosting = hosting
	_state.peer_count = peer_count


func _get_world() -> World:
	if ECS.world == null:
		push_error("[NetworkSession] ECS.world is null — ensure World is initialized before host()/join()")
		return null
	return ECS.world
