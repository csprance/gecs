class_name NetAdapter
extends Resource
## NetAdapter - Abstract interface for network operations.
##
## This adapter pattern decouples NetworkSync from any specific network implementation,
## allowing the gecs_network addon to work standalone without dependencies on
## game-specific singletons like "Net".
##
## Default Implementation:
## The default adapter uses Godot's built-in multiplayer singleton.
## Override methods to integrate with custom networking solutions (Talo, Steam, etc.).
##
## Usage:
##   # Use default (Godot multiplayer):
##   var adapter = NetAdapter.new()
##
##   # Or create custom adapter:
##   class TaloNetAdapter extends NetAdapter:
##       func is_server() -> bool:
##           return TaloMultiplayer.is_host()

## Cached multiplayer reference (invalidated on scene changes)
var _cached_multiplayer: MultiplayerAPI = null
var _cache_valid: bool = false
## Multiplayer property accessor (for compatibility with existing code)
var multiplayer: MultiplayerAPI:
	get:
		return get_multiplayer()

# ============================================================================
# CORE METHODS - Override these for custom implementations
# ============================================================================


## Returns true if this peer is the server/host.
## Default: Uses Godot's multiplayer.is_server()
func is_server() -> bool:
	if not _has_multiplayer():
		return true  # Single player = "server"
	return multiplayer.is_server()


## Returns the local peer's unique ID.
## Default: 1 for server, >1 for clients
func get_my_peer_id() -> int:
	if not _has_multiplayer():
		return 1  # Single player
	return multiplayer.get_unique_id()


## Returns true if connected to a multiplayer game.
## Default: Checks if multiplayer peer exists and is connected
func is_in_game() -> bool:
	if not _has_multiplayer():
		return false
	var peer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Returns array of connected peer IDs (excluding self).
## Default: Uses multiplayer.get_peers()
func get_connected_peers() -> Array[int]:
	if not _has_multiplayer():
		return []
	var peers: Array[int] = []
	for peer_id in multiplayer.get_peers():
		peers.append(peer_id)
	return peers


## Returns all peer IDs including self.
## Useful for broadcasting.
func get_all_peers() -> Array[int]:
	var peers = get_connected_peers()
	var my_id = get_my_peer_id()
	if my_id > 0 and not peers.has(my_id):
		peers.append(my_id)
	return peers


## Returns the peer ID of the sender of the most recent RPC.
## Default: Uses Godot's multiplayer.get_remote_sender_id()
func get_remote_sender_id() -> int:
	if not _has_multiplayer():
		return 0
	return multiplayer.get_remote_sender_id()


# ============================================================================
# HELPER METHODS
# ============================================================================


## Check if multiplayer singleton is available and valid.
## Handles edge cases during scene transitions.
func _has_multiplayer() -> bool:
	# Access via property to use cached value
	var mp = get_multiplayer()
	return mp != null


## Get the multiplayer node for RPC operations.
## Returns null if not available. Caches the result for performance.
## Note: The cache auto-detects when the SceneTree's MultiplayerAPI has been
## replaced (e.g., on disconnect/reconnect) and refreshes automatically.
func get_multiplayer() -> MultiplayerAPI:
	# Fetch the current tree reference for validation
	var tree: SceneTree = null
	if is_instance_valid(Engine.get_main_loop()):
		tree = Engine.get_main_loop() as SceneTree

	if tree == null:
		_cache_valid = false
		_cached_multiplayer = null
		return null

	# Validate cache: the SceneTree may have replaced its MultiplayerAPI
	# (e.g., after disconnect/reconnect). Since MultiplayerAPI is RefCounted,
	# is_instance_valid alone cannot detect this — compare identity instead.
	if _cache_valid and _cached_multiplayer == tree.get_multiplayer():
		return _cached_multiplayer

	# Refresh cache
	_cached_multiplayer = tree.get_multiplayer()
	_cache_valid = _cached_multiplayer != null
	return _cached_multiplayer


## Invalidate the cached multiplayer reference.
## Call this when switching scenes or reconnecting.
func invalidate_cache() -> void:
	_cache_valid = false
	_cached_multiplayer = null
