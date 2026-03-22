class_name ENetTransportProvider
extends TransportProvider
## ENetTransportProvider - Default transport using Godot's built-in ENet.
##
## Supports direct IP:port connections. Uses OfflineMultiplayerPeer for
## singleplayer when port=0.
##
## Config keys for create_host_peer():
##   port: int (default 7777, 0 = singleplayer/offline)
##   bind_address: String (default "0.0.0.0")
##   max_players: int (default 4)
##
## Config keys for create_client_peer():
##   address: String (default "127.0.0.1")
##   port: int (default 7777)


func create_host_peer(config: Dictionary) -> MultiplayerPeer:
	var port: int = config.get("port", 7777)
	var bind_address: String = config.get("bind_address", "0.0.0.0")
	var max_players: int = config.get("max_players", 4)

	if port == 0:
		return OfflineMultiplayerPeer.new()

	var peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_address)
	var error = peer.create_server(port, max_players)
	if error != OK:
		push_error("ENetTransportProvider: create_server failed on port %d: %s" % [port, error_string(error)])
		return null
	return peer


func create_client_peer(config: Dictionary) -> MultiplayerPeer:
	var address: String = config.get("address", "127.0.0.1")
	var port: int = config.get("port", 7777)

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		push_error("ENetTransportProvider: create_client failed for %s:%d: %s" % [address, port, error_string(error)])
		return null
	return peer


func get_transport_name() -> String:
	return "ENet"


func supports_direct_connect() -> bool:
	return true
