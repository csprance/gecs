extends GdUnitTestSuite

## Test suite for CN_NetworkIdentity
## Tests pure logic methods (is_server_owned, is_host, is_player)
## and adapter-based methods (is_local, has_authority).

# ============================================================================
# MOCK ADAPTER
# ============================================================================


class MockNetAdapter:
	extends NetAdapter

	var _is_server: bool = false
	var _my_peer_id: int = 1

	func is_server() -> bool:
		return _is_server

	func get_my_peer_id() -> int:
		return _my_peer_id

	func _has_multiplayer() -> bool:
		return true


# ============================================================================
# PURE LOGIC METHODS
# ============================================================================


func test_is_server_owned_peer_id_zero():
	var net_id = CN_NetworkIdentity.new(0)
	assert_bool(net_id.is_server_owned()).is_true()


func test_is_server_owned_peer_id_one():
	var net_id = CN_NetworkIdentity.new(1)
	assert_bool(net_id.is_server_owned()).is_true()


func test_is_server_owned_peer_id_two():
	var net_id = CN_NetworkIdentity.new(2)
	assert_bool(net_id.is_server_owned()).is_false()


func test_is_host_peer_id_one():
	var net_id = CN_NetworkIdentity.new(1)
	assert_bool(net_id.is_host()).is_true()


func test_is_host_peer_id_zero():
	var net_id = CN_NetworkIdentity.new(0)
	assert_bool(net_id.is_host()).is_false()


func test_is_host_peer_id_two():
	var net_id = CN_NetworkIdentity.new(2)
	assert_bool(net_id.is_host()).is_false()


func test_is_player_peer_id_zero():
	var net_id = CN_NetworkIdentity.new(0)
	assert_bool(net_id.is_player()).is_false()


func test_is_player_peer_id_one():
	var net_id = CN_NetworkIdentity.new(1)
	assert_bool(net_id.is_player()).is_true()


func test_is_player_peer_id_five():
	var net_id = CN_NetworkIdentity.new(5)
	assert_bool(net_id.is_player()).is_true()


# ============================================================================
# ADAPTER-BASED METHODS
# ============================================================================


func test_is_local_matches_own_peer():
	var adapter = MockNetAdapter.new()
	adapter._my_peer_id = 2
	var net_id = CN_NetworkIdentity.new(2)
	assert_bool(net_id.is_local(adapter)).is_true()


func test_is_local_does_not_match_other_peer():
	var adapter = MockNetAdapter.new()
	adapter._my_peer_id = 2
	var net_id = CN_NetworkIdentity.new(3)
	assert_bool(net_id.is_local(adapter)).is_false()


func test_has_authority_server_always_true():
	var adapter = MockNetAdapter.new()
	adapter._is_server = true
	adapter._my_peer_id = 1
	# Server has authority over any entity, even peer_id=5
	var net_id = CN_NetworkIdentity.new(5)
	assert_bool(net_id.has_authority(adapter)).is_true()


func test_has_authority_server_over_server_owned():
	var adapter = MockNetAdapter.new()
	adapter._is_server = true
	adapter._my_peer_id = 1
	var net_id = CN_NetworkIdentity.new(0)
	assert_bool(net_id.has_authority(adapter)).is_true()


func test_has_authority_client_own_entity():
	var adapter = MockNetAdapter.new()
	adapter._is_server = false
	adapter._my_peer_id = 2
	var net_id = CN_NetworkIdentity.new(2)
	assert_bool(net_id.has_authority(adapter)).is_true()


func test_has_authority_client_other_entity():
	var adapter = MockNetAdapter.new()
	adapter._is_server = false
	adapter._my_peer_id = 2
	var net_id = CN_NetworkIdentity.new(3)
	assert_bool(net_id.has_authority(adapter)).is_false()


func test_has_authority_client_server_owned_entity():
	var adapter = MockNetAdapter.new()
	adapter._is_server = false
	adapter._my_peer_id = 2
	var net_id = CN_NetworkIdentity.new(0)
	assert_bool(net_id.has_authority(adapter)).is_false()


# ============================================================================
# INIT DEFAULTS
# ============================================================================


func test_default_peer_id_is_zero():
	var net_id = CN_NetworkIdentity.new()
	assert_int(net_id.peer_id).is_equal(0)


func test_init_sets_peer_id():
	var net_id = CN_NetworkIdentity.new(42)
	assert_int(net_id.peer_id).is_equal(42)


func test_default_spawn_index_is_zero():
	var net_id = CN_NetworkIdentity.new()
	assert_int(net_id.spawn_index).is_equal(0)
