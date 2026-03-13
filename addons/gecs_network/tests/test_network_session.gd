extends GdUnitTestSuite

## Test suite for NetworkSession host/join/end_session API.
## Covers the 9 behavioral contracts from 07-02-PLAN.md.
##
## Tests use MockTransport (returns OfflineMultiplayerPeer or null) to avoid
## real ENet dependency. NetworkSession is added to the scene tree so that
## its `multiplayer` property is backed by a real MultiplayerAPI.

# ============================================================================
# MOCK OBJECTS
# ============================================================================


class MockTransport:
	extends TransportProvider

	var _return_null: bool = false
	var create_host_peer_called: bool = false
	var create_client_peer_called: bool = false

	func create_host_peer(_config: Dictionary) -> MultiplayerPeer:
		create_host_peer_called = true
		if _return_null:
			return null
		return OfflineMultiplayerPeer.new()

	func create_client_peer(_config: Dictionary) -> MultiplayerPeer:
		create_client_peer_called = true
		if _return_null:
			return null
		return OfflineMultiplayerPeer.new()


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================


var session: NetworkSession
var mock_transport: MockTransport


func before_test():
	mock_transport = MockTransport.new()
	session = NetworkSession.new()
	session.transport = mock_transport
	session.auto_start_network_sync = false
	add_child(session)


func after_test():
	if is_instance_valid(session):
		# Clean up multiplayer peer to avoid dangling ENet warnings
		session.multiplayer.multiplayer_peer = null
		session.queue_free()
	session = null
	mock_transport = null


# ============================================================================
# PLAN 02: host() / join() / end_session() + callable hooks (9 tests)
# ============================================================================


func test_host_returns_ok() -> void:
	mock_transport._return_null = false
	var result = session.host(7777)
	assert_int(result).is_equal(OK)


func test_host_returns_error_on_null_peer() -> void:
	mock_transport._return_null = true
	var result = session.host(7777)
	assert_int(result).is_equal(ERR_CANT_CONNECT)


func test_join_returns_ok() -> void:
	mock_transport._return_null = false
	var result = session.join("127.0.0.1", 7777)
	assert_int(result).is_equal(OK)


func test_on_before_host_fires() -> void:
	var called = [false]
	session.on_before_host = func(): called[0] = true
	session.host(7777)
	assert_bool(called[0]).is_true()


func test_on_host_success_fires() -> void:
	var called = [false]
	session.on_host_success = func(): called[0] = true
	session.host(7777)
	assert_bool(called[0]).is_true()


func test_on_peer_connected_fires_with_id() -> void:
	var received_id = [-1]
	session.on_peer_connected = func(peer_id: int): received_id[0] = peer_id
	# Connect session so multiplayer signals are wired
	session.host(7777)
	# Directly invoke the private signal handler (simulates the multiplayer signal)
	session._on_peer_connected_signal(42)
	assert_int(received_id[0]).is_equal(42)


func test_on_peer_disconnected_fires_with_id() -> void:
	var received_id = [-1]
	session.on_peer_disconnected = func(peer_id: int): received_id[0] = peer_id
	session.host(7777)
	session._on_peer_disconnected_signal(99)
	assert_int(received_id[0]).is_equal(99)


func test_on_session_ended_fires() -> void:
	var called = [false]
	session.on_session_ended = func(): called[0] = true
	session.host(7777)
	session.end_session()
	assert_bool(called[0]).is_true()


func test_empty_hooks_no_crash() -> void:
	# All hooks are default Callable() — must not crash
	assert_int(session.host(7777)).is_equal(OK)
	assert_int(session.join("127.0.0.1", 7777)).is_equal(OK)
	session.end_session()
	# If we reach here without crash, test passes
	assert_bool(true).is_true()


# ============================================================================
# PLAN 03 stubs: ECS component event tests (RED until Plan 03 implements them)
# ============================================================================


func test_cn_peer_joined_added() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_cn_peer_left_added() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_cn_session_started_on_host() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_cn_session_ended_on_disconnect() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_cn_session_state_connected() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_cn_session_state_disconnected() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_transient_events_cleared() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_session_entity_not_networked() -> void:
	assert_bool(false).is_true()  # Plan 03 stub


func test_network_sync_property() -> void:
	assert_bool(false).is_true()  # Plan 03 stub
