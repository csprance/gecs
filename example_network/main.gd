extends Node3D
## Main entry point for the GECS Network Example.
## Demonstrates multiplayer with continuous sync (players) and spawn-only sync (projectiles).

const PLAYER_SCENE_PATH := "res://example_network/entities/e_player.tscn"
const DEFAULT_PORT := 7777

var _network_sync: NetworkSync
var _network_middleware: ExampleMiddleware
var _is_connected: bool = false
var _spawned_peer_ids: Dictionary = {}  # peer_id -> entity_id
var _next_player_number: int = 1  # Track join order (1-4) for color assignment

@onready var world: World = $World
@onready var entities: Node = $World/Entities

# UI references
@onready var lobby_ui: Control = $UI/LobbyUI
@onready var ip_input: LineEdit = $UI/LobbyUI/CenterContainer/VBoxContainer/IPInput
@onready var host_button: Button = $UI/LobbyUI/CenterContainer/VBoxContainer/HBoxContainer/HostButton
@onready var join_button: Button = $UI/LobbyUI/CenterContainer/VBoxContainer/HBoxContainer/JoinButton
@onready var disconnect_button: Button = $UI/LobbyUI/CenterContainer/VBoxContainer/DisconnectButton
@onready var status_label: Label = $UI/LobbyUI/CenterContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	# Initialize ECS
	ECS.world = world
	world.initialize()

	# Connect UI buttons
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Default IP
	ip_input.text = "127.0.0.1"


func _process(delta: float) -> void:
	if not _is_connected:
		return

	# Process ECS systems in order
	world.process(delta, "input")
	world.process(delta, "gameplay")
	world.process(delta, "physics")


# =============================================================================
# LOBBY UI HANDLERS
# =============================================================================


func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, 3)  # Max 3 clients + host = 4 players
	if error != OK:
		status_label.text = "Failed to host: %s" % error_string(error)
		return

	multiplayer.multiplayer_peer = peer
	_setup_network_sync()
	_is_connected = true
	_update_ui_connected(true)
	status_label.text = "Hosting on port %d" % DEFAULT_PORT

	# Host spawns own player immediately
	_spawn_player_for_peer(1)


func _on_join_pressed() -> void:
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, DEFAULT_PORT)
	if error != OK:
		status_label.text = "Failed to connect: %s" % error_string(error)
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Connecting to %s..." % ip


func _on_disconnect_pressed() -> void:
	_cleanup_network()
	_update_ui_disconnected()
	status_label.text = "Disconnected"


func _update_ui_connected(is_host: bool) -> void:
	host_button.visible = false
	join_button.visible = false
	ip_input.visible = false
	disconnect_button.visible = true


func _update_ui_disconnected() -> void:
	host_button.visible = true
	join_button.visible = true
	ip_input.visible = true
	disconnect_button.visible = false


# =============================================================================
# MULTIPLAYER SIGNAL HANDLERS
# =============================================================================


func _on_peer_connected(peer_id: int) -> void:
	print("[Main] Peer connected: %d" % peer_id)
	# Host spawns players for all connected peers
	if multiplayer.is_server():
		_spawn_player_for_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[Main] Peer disconnected: %d" % peer_id)
	# Remove player entity for disconnected peer
	if _spawned_peer_ids.has(peer_id):
		var entity_id = _spawned_peer_ids[peer_id]
		var entity = world.get_entity_by_id(entity_id)
		if entity:
			world.remove_entity(entity)
			entity.queue_free()
		_spawned_peer_ids.erase(peer_id)


func _on_connected_to_server() -> void:
	print("[Main] Connected to server as peer %d" % multiplayer.get_unique_id())
	_setup_network_sync()
	_is_connected = true
	_update_ui_connected(false)
	status_label.text = "Connected as peer %d" % multiplayer.get_unique_id()


func _on_connection_failed() -> void:
	print("[Main] Connection failed")
	status_label.text = "Connection failed"
	_cleanup_network()
	_update_ui_disconnected()


func _on_server_disconnected() -> void:
	print("[Main] Server disconnected")
	status_label.text = "Server disconnected"
	_cleanup_network()
	_update_ui_disconnected()


# =============================================================================
# NETWORK SETUP
# =============================================================================


func _setup_network_sync() -> void:
	if _network_sync:
		return

	# Create NetworkSync with project-specific config
	_network_sync = NetworkSync.attach_to_world(world, ExampleSyncConfig.new())
	_network_sync.debug_logging = true  # Enable for demo visibility

	# Create middleware for visual setup
	_network_middleware = ExampleMiddleware.new(_network_sync)

	# Connect to local player spawned signal
	_network_sync.local_player_spawned.connect(_on_local_player_spawned)


func _cleanup_network() -> void:
	_is_connected = false

	# Clear spawned players
	for peer_id in _spawned_peer_ids.keys():
		var entity_id = _spawned_peer_ids[peer_id]
		var entity = world.get_entity_by_id(entity_id)
		if entity:
			world.remove_entity(entity)
			entity.queue_free()
	_spawned_peer_ids.clear()

	# Reset player number counter
	_next_player_number = 1

	# Reset multiplayer
	multiplayer.multiplayer_peer = null

	# PROPERLY remove NetworkSync (triggers _exit_tree which disconnects signals)
	if _network_sync:
		_network_sync.queue_free()
	_network_sync = null
	_network_middleware = null


func _on_local_player_spawned(entity: Entity) -> void:
	print("[Main] Local player spawned: %s" % entity.name)


# =============================================================================
# PLAYER SPAWNING
# =============================================================================


func _spawn_player_for_peer(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		print("[Main] Player already spawned for peer %d" % peer_id)
		return

	# Assign next player number (1-4) based on join order
	var player_number = _next_player_number
	_next_player_number += 1

	print("[Main] Spawning player for peer %d (player #%d)" % [peer_id, player_number])

	var PlayerScene: PackedScene = preload(PLAYER_SCENE_PATH)
	var player = PlayerScene.instantiate() as Entity

	# Set node name to peer_id (used by entity to set authority)
	player.name = str(peer_id)

	# Add to scene tree first
	entities.add_child(player)

	# Set spawn position (spread players out)
	var spawn_offset = Vector3((player_number % 4) * 2.0 - 3.0, 0, (player_number / 4) * 2.0 - 1.0)
	player.global_position = spawn_offset

	# Add to ECS world - triggers NetworkSync broadcast
	world.add_entity(player)

	# CRITICAL: Set player number AFTER add_entity() so it syncs with spawn RPC
	var player_num_comp = player.get_component(C_PlayerNumber) as C_PlayerNumber
	if player_num_comp:
		player_num_comp.player_number = player_number

	# Track spawned peer
	_spawned_peer_ids[peer_id] = player.id
