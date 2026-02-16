class_name CN_NetworkIdentity
extends Component
## Network identity component for multiplayer synchronization.
## Stores the peer ID that controls this entity.
##
## This is a pure data component with no external dependencies,
## making it usable as part of the standalone gecs_network addon.
##
## Authority Model:
## - peer_id = 0: Server-owned (enemies, projectiles, world entities)
## - peer_id = 1: Host player (also acts as server)
## - peer_id > 1: Client player
##
## Usage in systems:
##   # Check if entity is controlled by local player:
##   if net_id.is_local():
##       velocity.direction = Input.get_vector(...)
##
##   # Or use marker components in queries (ECS-idiomatic approach):
##   # query: q.with_all([C_Velocity, CN_LocalAuthority])
##
##   # Pure logic checks (no network state needed):
##   if net_id.is_player():
##       # Process player-owned entities

## The multiplayer peer ID that owns/controls this entity.
## 0 = server-owned (enemies, projectiles), 1+ = player peer IDs
@export var peer_id: int = 0

## The network spawn index (used for entity identification).
## Helps with deterministic entity ordering.
@export var spawn_index: int = 0


func _init(p_peer_id: int = 0) -> void:
	peer_id = p_peer_id


# ============================================================================
# PURE LOGIC METHODS (No external dependencies)
# ============================================================================


## Check if this entity is owned by the server.
## Server owns enemies, projectiles, and world entities (peer_id = 0 or 1).
## Note: peer_id = 1 is the host, who is also the server.
func is_server_owned() -> bool:
	return peer_id == 0 or peer_id == 1


## Check if this is the host/server peer.
## The host has peer_id = 1 and runs the server logic.
func is_host() -> bool:
	return peer_id == 1


## Check if this entity is a player (not server-owned NPC).
## Players have peer_id > 0 (host = 1, clients > 1).
func is_player() -> bool:
	return peer_id > 0


# ============================================================================
# ADAPTER-BASED METHODS (For addon compatibility)
# ============================================================================

## Shared default adapter to avoid allocation per call in hot loops.
## Note: NetAdapter.get_multiplayer() auto-detects stale MultiplayerAPI
## references, so this static instance is safe across scene transitions.
## Call reset_default_adapter() for explicit cleanup if needed.
static var _default_adapter: NetAdapter = null


static func _get_default_adapter() -> NetAdapter:
	if _default_adapter == null:
		_default_adapter = NetAdapter.new()
	return _default_adapter


## Reset the shared default adapter, forcing a fresh instance on next use.
## Call this during explicit session teardown (host migration, reconnect)
## if the automatic stale-detection in NetAdapter is insufficient.
static func reset_default_adapter() -> void:
	if _default_adapter != null:
		_default_adapter.invalidate_cache()
	_default_adapter = null


## Check if this entity is controlled by the local player.
## Returns true if this entity's peer_id matches the local peer.
## @param adapter: NetAdapter instance for network state queries
##                 (optional - creates default if null)
func is_local(adapter: NetAdapter = null) -> bool:
	if adapter == null:
		adapter = _get_default_adapter()
	return peer_id == adapter.get_my_peer_id()


## Check if we have authority to modify this entity.
## Server can modify anything, clients can only modify their own entities.
## @param adapter: NetAdapter instance for network state queries
##                 (optional - creates default if null)
func has_authority(adapter: NetAdapter = null) -> bool:
	if adapter == null:
		adapter = _get_default_adapter()
	# Server has authority over everything
	if adapter.is_server():
		return true

	# Clients only have authority over their own entities
	return is_local(adapter)
