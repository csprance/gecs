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
	peers.assign(multiplayer.get_peers())
	return peers


## Returns all peer IDs including self.
## Useful for broadcasting.
func get_all_peers() -> Array[int]:
	if not _has_multiplayer():
		return []
	var peers = get_connected_peers()
	var my_id = get_my_peer_id()
	if my_id > 0 and not peers.has(my_id):
		peers.append(my_id)
	return peers


# ============================================================================
# RPC METHODS - Stubs for custom implementations
# ============================================================================


## Send RPC to a specific peer.
## Override for custom networking.
## @param peer_id: Target peer ID
## @param method: Method name to call
## @param args: Arguments to pass
func rpc_to_peer(_peer_id: int, _method: String, _args: Array) -> void:
	# Default implementation does nothing - NetworkSync uses Godot's @rpc directly
	# Override this for custom networking solutions
	push_warning(
		"NetAdapter.rpc_to_peer() called but not implemented. Override for custom networking."
	)


## Send RPC to all connected peers.
## Override for custom networking.
## @param method: Method name to call
## @param args: Arguments to pass
func rpc_to_all(_method: String, _args: Array) -> void:
	# Default implementation does nothing - NetworkSync uses Godot's @rpc directly
	# Override this for custom networking solutions
	push_warning("NetAdapter.rpc_to_all() called but not implemented. Override for custom networking.")


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
func get_multiplayer() -> MultiplayerAPI:
	# Return cached value if valid
	if _cache_valid and is_instance_valid(_cached_multiplayer):
		return _cached_multiplayer

	# Fetch fresh reference
	if not is_instance_valid(Engine.get_main_loop()):
		_cache_valid = false
		_cached_multiplayer = null
		return null

	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_cache_valid = false
		_cached_multiplayer = null
		return null

	_cached_multiplayer = tree.get_multiplayer()
	_cache_valid = _cached_multiplayer != null
	return _cached_multiplayer


## Invalidate the cached multiplayer reference.
## Call this when switching scenes or reconnecting.
func invalidate_cache() -> void:
	_cache_valid = false
	_cached_multiplayer = null
