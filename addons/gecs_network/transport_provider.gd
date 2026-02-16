class_name TransportProvider
extends RefCounted
## TransportProvider - Abstract interface for creating multiplayer peers.
##
## Override this class to add support for different network transports
## (ENet, Steam, WebRTC, etc.) without changing game code.
##
## Usage:
##   # Use built-in ENet (default):
##   var transport = ENetTransportProvider.new()
##
##   # Or create custom transport:
##   class MyTransport extends TransportProvider:
##       func create_host_peer(config: Dictionary) -> MultiplayerPeer:
##           return MyCustomPeer.new()


## Whether this transport's dependencies are available at runtime.
## Override to check for optional dependencies (e.g., GodotSteam).
func is_available() -> bool:
	return true


## Create a MultiplayerPeer for hosting. Returns null on failure.
## @param config: Dictionary with transport-specific options (e.g., port, bind_address, max_players)
func create_host_peer(_config: Dictionary) -> MultiplayerPeer:
	push_warning("TransportProvider.create_host_peer() not implemented")
	return null


## Create a MultiplayerPeer for joining. Returns null on failure.
## @param config: Dictionary with transport-specific options (e.g., address, port)
func create_client_peer(_config: Dictionary) -> MultiplayerPeer:
	push_warning("TransportProvider.create_client_peer() not implemented")
	return null


## Display name for this transport (for UI/logging).
func get_transport_name() -> String:
	return "Unknown"


## Whether this transport supports direct IP:port connections.
func supports_direct_connect() -> bool:
	return false


## Whether this transport supports lobby-based matchmaking.
func supports_lobbies() -> bool:
	return false
