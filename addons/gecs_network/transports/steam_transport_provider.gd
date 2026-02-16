class_name SteamTransportProvider
extends TransportProvider
## SteamTransportProvider - Transport using GodotSteam's SteamMultiplayerPeer.
##
## Uses dynamic class loading (ClassDB) to avoid a hard dependency on GodotSteam.
## This script compiles and loads even if GodotSteam is not installed.
## Call is_available() to check at runtime.
##
## Config keys for create_host_peer():
##   steam_port: int (default 0)
##   options: Array (default [])
##
## Config keys for create_client_peer():
##   steam_id: int (required - Steam ID of the host)
##   steam_port: int (default 0)
##   options: Array (default [])


## Check if GodotSteam's SteamMultiplayerPeer is available.
func is_available() -> bool:
	return ClassDB.class_exists("SteamMultiplayerPeer")


func create_host_peer(config: Dictionary) -> MultiplayerPeer:
	if not is_available():
		push_error("SteamTransportProvider: GodotSteam not installed (SteamMultiplayerPeer not found)")
		return null

	var peer = ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if peer == null:
		push_error("SteamTransportProvider: Failed to instantiate SteamMultiplayerPeer")
		return null
	var result = peer.call("create_host", config.get("steam_port", 0), config.get("options", []))
	if result is int and result != OK:
		push_error("SteamTransportProvider: create_host failed with error code %s" % result)
		peer.free()
		return null
	return peer


func create_client_peer(config: Dictionary) -> MultiplayerPeer:
	if not is_available():
		push_error("SteamTransportProvider: GodotSteam not installed (SteamMultiplayerPeer not found)")
		return null

	var steam_id: int = config.get("steam_id", 0)
	if steam_id == 0:
		push_error("SteamTransportProvider: steam_id is required but was missing or zero in config")
		return null
	var peer = ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if peer == null:
		push_error("SteamTransportProvider: Failed to instantiate SteamMultiplayerPeer")
		return null
	var result = peer.call("create_client", steam_id, config.get("steam_port", 0), config.get("options", []))
	if result is int and result != OK:
		push_error("SteamTransportProvider: create_client failed with error code %s" % result)
		peer.free()
		return null
	return peer


func get_transport_name() -> String:
	return "Steam"


func supports_lobbies() -> bool:
	return true
