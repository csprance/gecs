extends GdUnitTestSuite

## Test suite for NetworkSession host/join/end_session API.
## Covers the 9 behavioral contracts from 07-02-PLAN.md (Plan 02)
## and the 9 ECS event component contracts from 07-03-PLAN.md (Plan 03).
##
## Tests use MockTransport (returns OfflineMultiplayerPeer or null) to avoid
## real ENet dependency. NetworkSession is added to the scene tree so that
## its `multiplayer` property is backed by a real MultiplayerAPI.
## A real World is created and assigned to ECS.world so that the session entity
## management code works correctly.

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
var world: World


func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

	mock_transport = MockTransport.new()
	session = NetworkSession.new()
	session.transport = mock_transport
	session.auto_start_network_sync = false
	add_child(session)


func after_test():
	if is_instance_valid(session):
		# Restore the default OfflineMultiplayerPeer so subsequent test suites see a
		# clean singleplayer multiplayer state. Setting to null would leave the
		# SceneTree with no peer, causing NetAdapter.get_unique_id() to return 0.
		session.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	# Reset the static default adapter to avoid stale multiplayer state across tests
	CN_NetworkIdentity.reset_default_adapter()

	# Manually remove all world entities before freeing to avoid stale-entity warnings
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	ECS.world = null
	world = null

	if is_instance_valid(session):
		session.free()
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
# PLAN 03: ECS component event tests (Session entity + transient components)
# ============================================================================


func test_cn_peer_joined_added() -> void:
	# After host() establishes the session and _on_peer_connected_signal fires,
	# the session entity must have CN_PeerJoined with the correct peer_id.
	session.host(7777)
	session._on_peer_connected_signal(42)
	var entity: Entity = session._session_entity
	assert_object(entity).is_not_null()
	var comp = entity.get_component(CN_PeerJoined) as CN_PeerJoined
	assert_object(comp).is_not_null()
	assert_int(comp.peer_id).is_equal(42)


func test_cn_peer_left_added() -> void:
	# After _on_peer_disconnected_signal fires, session entity has CN_PeerLeft.
	session.host(7777)
	session._on_peer_disconnected_signal(42)
	var entity: Entity = session._session_entity
	assert_object(entity).is_not_null()
	var comp = entity.get_component(CN_PeerLeft) as CN_PeerLeft
	assert_object(comp).is_not_null()
	assert_int(comp.peer_id).is_equal(42)


func test_cn_session_started_on_host() -> void:
	# After host() succeeds, session entity has CN_SessionStarted with is_host=true.
	session.host(7777)
	var entity: Entity = session._session_entity
	assert_object(entity).is_not_null()
	var comp = entity.get_component(CN_SessionStarted) as CN_SessionStarted
	assert_object(comp).is_not_null()
	assert_bool(comp.is_host).is_true()


func test_cn_session_ended_on_disconnect() -> void:
	# After end_session(), session entity has CN_SessionEnded component.
	session.host(7777)
	var entity: Entity = session._session_entity
	session.end_session()
	assert_object(entity).is_not_null()
	var comp = entity.get_component(CN_SessionEnded) as CN_SessionEnded
	assert_object(comp).is_not_null()


func test_cn_session_state_connected() -> void:
	# After host(), CN_SessionState has is_connected=true, is_hosting=true.
	session.host(7777)
	var entity: Entity = session._session_entity
	assert_object(entity).is_not_null()
	var state = entity.get_component(CN_SessionState) as CN_SessionState
	assert_object(state).is_not_null()
	assert_bool(state.is_connected).is_true()
	assert_bool(state.is_hosting).is_true()


func test_cn_session_state_disconnected() -> void:
	# After end_session(), CN_SessionState has is_connected=false, is_hosting=false.
	session.host(7777)
	var entity: Entity = session._session_entity
	session.end_session()
	assert_object(entity).is_not_null()
	var state = entity.get_component(CN_SessionState) as CN_SessionState
	assert_object(state).is_not_null()
	assert_bool(state.is_connected).is_false()
	assert_bool(state.is_hosting).is_false()


func test_transient_events_cleared() -> void:
	# CN_PeerJoined added in one "frame" is absent after _process() runs.
	session.host(7777)
	session._on_peer_connected_signal(7)
	var entity: Entity = session._session_entity
	# Verify it was added
	assert_object(entity.get_component(CN_PeerJoined)).is_not_null()
	# Simulate next frame's _process() call
	session._process(0.016)
	# Transient component must be cleared
	assert_object(entity.get_component(CN_PeerJoined)).is_null()


func test_session_entity_not_networked() -> void:
	# Session entity must NOT have CN_NetworkIdentity at any time.
	var entity: Entity = session._session_entity
	assert_object(entity).is_not_null()
	assert_object(entity.get_component(CN_NetworkIdentity)).is_null()
	session.host(7777)
	assert_object(entity.get_component(CN_NetworkIdentity)).is_null()
	session.end_session()
	assert_object(entity.get_component(CN_NetworkIdentity)).is_null()


func test_network_sync_property() -> void:
	# network_sync returns null before host(), and a NetworkSync after host().
	assert_object(session.network_sync).is_null()
	# Enable auto_start_network_sync for this specific test
	session.auto_start_network_sync = true
	session.host(7777)
	assert_object(session.network_sync).is_not_null()
