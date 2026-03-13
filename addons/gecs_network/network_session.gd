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
	pass


func _process(_delta: float) -> void:
	pass

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start hosting a session. Uses default_port if port == -1.
## Returns OK on success, or an Error code on failure.
func host(port: int = -1) -> Error:
	return OK


## Join an existing session at ip:port. Uses default_port if port == -1.
## Returns OK on success, or an Error code on failure.
func join(ip: String, port: int = -1) -> Error:
	return OK


## End the active session and clean up all network resources.
func end_session() -> void:
	pass

# ---------------------------------------------------------------------------
# Internal signal wiring
# ---------------------------------------------------------------------------

func _connect_multiplayer_signals() -> void:
	pass


func _disconnect_multiplayer_signals() -> void:
	pass


func _on_peer_connected_signal(peer_id: int) -> void:
	pass


func _on_peer_disconnected_signal(peer_id: int) -> void:
	pass


func _on_connected_to_server() -> void:
	pass


func _on_connection_failed() -> void:
	pass


func _on_server_disconnected() -> void:
	pass

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _update_session_state(connected: bool, hosting: bool, peer_count: int) -> void:
	pass


func _get_world() -> World:
	return ECS.world
