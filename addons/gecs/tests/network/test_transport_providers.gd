extends GdUnitTestSuite

## Test suite for TransportProvider, ENetTransportProvider, SteamTransportProvider
## Tests base class defaults, ENet peer creation, and Steam availability checking.

# ============================================================================
# BASE TRANSPORT PROVIDER
# ============================================================================


func test_base_is_available():
	var provider = TransportProvider.new()
	assert_bool(provider.is_available()).is_true()


func test_base_create_host_peer_returns_null():
	var provider = TransportProvider.new()
	var peer = provider.create_host_peer({})
	assert_object(peer).is_null()


func test_base_create_client_peer_returns_null():
	var provider = TransportProvider.new()
	var peer = provider.create_client_peer({})
	assert_object(peer).is_null()


func test_base_get_transport_name():
	var provider = TransportProvider.new()
	assert_str(provider.get_transport_name()).is_equal("Unknown")


func test_base_supports_direct_connect():
	var provider = TransportProvider.new()
	assert_bool(provider.supports_direct_connect()).is_false()


func test_base_supports_lobbies():
	var provider = TransportProvider.new()
	assert_bool(provider.supports_lobbies()).is_false()


# ============================================================================
# ENET TRANSPORT PROVIDER
# ============================================================================


func test_enet_create_host_peer_offline():
	var provider = ENetTransportProvider.new()
	var peer = provider.create_host_peer({"port": 0})
	assert_object(peer).is_not_null()
	assert_object(peer).is_instanceof(OfflineMultiplayerPeer)


func test_enet_get_transport_name():
	var provider = ENetTransportProvider.new()
	assert_str(provider.get_transport_name()).is_equal("ENet")


func test_enet_supports_direct_connect():
	var provider = ENetTransportProvider.new()
	assert_bool(provider.supports_direct_connect()).is_true()


func test_enet_supports_lobbies():
	var provider = ENetTransportProvider.new()
	assert_bool(provider.supports_lobbies()).is_false()


func test_enet_is_available():
	var provider = ENetTransportProvider.new()
	# ENet is always available (built-in to Godot)
	assert_bool(provider.is_available()).is_true()


# ============================================================================
# STEAM TRANSPORT PROVIDER
# ============================================================================


func test_steam_is_available_without_godot_steam():
	var provider = SteamTransportProvider.new()
	# In test env, GodotSteam is not installed
	assert_bool(provider.is_available()).is_false()


func test_steam_create_host_peer_returns_null_when_unavailable():
	var provider = SteamTransportProvider.new()
	var peer = provider.create_host_peer({})
	assert_object(peer).is_null()


func test_steam_create_client_peer_returns_null_when_unavailable():
	var provider = SteamTransportProvider.new()
	var peer = provider.create_client_peer({})
	assert_object(peer).is_null()


func test_steam_get_transport_name():
	var provider = SteamTransportProvider.new()
	assert_str(provider.get_transport_name()).is_equal("Steam")


func test_steam_supports_lobbies():
	var provider = SteamTransportProvider.new()
	assert_bool(provider.supports_lobbies()).is_true()


func test_steam_supports_direct_connect():
	var provider = SteamTransportProvider.new()
	assert_bool(provider.supports_direct_connect()).is_false()
