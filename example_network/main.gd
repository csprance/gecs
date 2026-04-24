## Main entry point for the GECS Network Example.
## Demonstrates multiplayer with continuous sync (players) and spawn-only sync (projectiles).
## Uses NetworkSession to eliminate manual ENet/signal/NetworkSync boilerplate.
extends Node3D

const PLAYER_SCENE_PATH := "res://example_network/entities/e_player.tscn"

var _spawned_peer_ids: Dictionary = {}  # peer_id -> entity_id
var _next_player_number: int = 1  # Track join order (1-4) for color assignment

@onready var world: World = $World
@onready var session: NetworkSession = $NetworkSession

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

	# Configure NetworkSession hooks
	session.debug_logging = true
	session.on_host_success = _on_host_success
	session.on_join_success = _on_join_success
	session.on_peer_connected = _on_peer_connected_hook
	session.on_peer_disconnected = _on_peer_disconnected_hook
	session.on_session_ended = _on_session_ended_hook

	# Connect UI buttons
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	# Default IP
	ip_input.text = "127.0.0.1"


func _process(delta: float) -> void:
	# Don't do any ECS stuff until we connect
	if session.network_sync == null:
		return

	# Process ECS systems in order
	world.process(delta, "input")
	world.process(delta, "gameplay")
	world.process(delta, "physics")


# =============================================================================
# LOBBY UI HANDLERS
# =============================================================================


## This function kicks off the hosting of a server for clients to join and
## What to do if that fails.
func _on_host_pressed() -> void:
	var error = session.host()
	if error != OK:
		status_label.text = "Failed to host: %s" % error_string(error)


## This function runs when a client clicks Join to join a server someone is
## hosting as well as what happens if that fails
func _on_join_pressed() -> void:
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var error = session.join(ip)
	if error != OK:
		status_label.text = "Failed to connect: %s" % error_string(error)
	else:
		status_label.text = "Connecting to %s..." % ip


## What do you do when you disconnect from the server
func _on_disconnect_pressed() -> void:
	session.end_session()


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
# NETWORKSESSION HOOK HANDLERS
# =============================================================================


func _on_host_success() -> void:
	_update_ui_connected(true)
	status_label.text = "Hosting on port %d" % session.default_port
	# Connect NetworkSync signals for spawn notifications
	session.network_sync.entity_spawned.connect(_on_entity_spawned)
	session.network_sync.local_player_spawned.connect(_on_local_player_spawned)
	# Host spawns own player immediately
	_spawn_player_for_peer(1)


func _on_join_success() -> void:
	_update_ui_connected(false)
	status_label.text = "Connected as peer %d" % multiplayer.get_unique_id()
	# Connect NetworkSync signals for spawn notifications
	session.network_sync.entity_spawned.connect(_on_entity_spawned)
	session.network_sync.local_player_spawned.connect(_on_local_player_spawned)


func _on_peer_connected_hook(peer_id: int) -> void:
	print("[Main] Peer connected: %d" % peer_id)
	# Host spawns players for all connected peers
	if multiplayer.is_server():
		_spawn_player_for_peer(peer_id)


func _on_peer_disconnected_hook(peer_id: int) -> void:
	print("[Main] Peer disconnected: %d" % peer_id)
	# Entity cleanup is handled automatically by SpawnManager.on_peer_disconnected
	# (via NetworkSync's peer_disconnected handler). Only update local tracking here.
	_spawned_peer_ids.erase(peer_id)


func _on_session_ended_hook() -> void:
	_update_ui_disconnected()
	status_label.text = "Disconnected"
	_spawned_peer_ids.clear()
	_next_player_number = 1


# =============================================================================
# NETWORKSYNC EVENT HANDLERS
# =============================================================================


func _on_entity_spawned(entity: Entity) -> void:
	print("[Main] Entity spawned via network: %s" % entity.name)


func _on_local_player_spawned(entity: Entity) -> void:
	print("[Main] Local player spawned: %s" % entity.name)


# =============================================================================
# PLAYER SPAWNING
# =============================================================================


## This spawns the player for a specific peer.
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
	player.name = str(peer_id)

	# Add to ECS world with component overrides
	world.add_entity(
		player,
		[
			CN_NetworkIdentity.new(peer_id),
			C_PlayerNumber.new(player_number),
			C_PlayerColor.new(_get_color_for_player_number(player_number))
		]
	)

	# Set spawn position (must be after add_entity since that adds to tree)
	# We could do this in an init system, or just do it here for the example
	var spawn_offset = Vector3(
		(player_number % 4) * 2.0 - 3.0, 0, (float(player_number) / 4.0) * 2.0 - 1.0
	)
	player.global_position = spawn_offset
	# Also write to the sync component so remote clients receive it
	var net_pos = player.get_component(C_NetPosition) as C_NetPosition
	if net_pos:
		net_pos.position = spawn_offset

	# Track spawned peers
	_spawned_peer_ids[peer_id] = player.id


## Based on a player number get the color that player should be
func _get_color_for_player_number(player_number: int) -> Color:
	match player_number:
		1:
			return Color(0.2, 0.6, 1.0)  # Blue
		2:
			return Color(1.0, 0.4, 0.4)  # Red
		3:
			return Color(0.4, 1.0, 0.4)  # Green
		4:
			return Color(1.0, 1.0, 0.4)  # Yellow
		_:
			return Color.WHITE
