extends GdUnitTestSuite

## Wave 0 stubs for LIFE-05 authority marker injection.
## All tests fail until Plan 02 implements _inject_authority_markers() in SpawnManager.


# ============================================================================
# MOCK OBJECTS
# ============================================================================


class MockNetAdapter:
	extends NetAdapter

	var _is_server: bool = false
	var _my_peer_id: int = 2

	func is_server() -> bool:
		return _is_server

	func get_my_peer_id() -> int:
		return _my_peer_id

	func get_remote_sender_id() -> int:
		return 0

	func _has_multiplayer() -> bool:
		return true


class MockNetworkSync:
	extends RefCounted

	var _world: World
	var _applying_network_data: bool = false
	var _game_session_id: int = 42
	var _spawn_counter: int = 0
	var _broadcast_pending: Dictionary = {}
	var net_adapter: MockNetAdapter

	func _init(w: World) -> void:
		_world = w
		net_adapter = MockNetAdapter.new()

	func rpc_broadcast_despawn(_id, _sid) -> void:
		pass


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var world: World
var mock_ns: MockNetworkSync
var manager: SpawnManager


func before_test() -> void:
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)
	manager = SpawnManager.new(mock_ns)


func after_test() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await get_tree().process_frame


# ============================================================================
# WAVE 0 STUBS — go GREEN in Plan 02
# ============================================================================


func test_local_authority_added_for_local_peer() -> void:
	## CN_LocalAuthority is added when net_id.peer_id == local peer id (peer 2 on a client).
	assert_bool(false).is_true()  # STUB: implement after Plan 02


func test_server_authority_added_for_server_owned() -> void:
	## CN_ServerAuthority is added when net_id.peer_id == 0 (server-owned entity).
	assert_bool(false).is_true()  # STUB: implement after Plan 02


func test_server_gets_local_authority_on_server_owned() -> void:
	## Server peer (is_server=true) gets CN_LocalAuthority on peer_id=0 entities.
	assert_bool(false).is_true()  # STUB: implement after Plan 02


func test_client_no_local_authority_on_other_peer() -> void:
	## Client does NOT receive CN_LocalAuthority for an entity owned by a different peer.
	assert_bool(false).is_true()  # STUB: implement after Plan 02


func test_marker_injection_idempotent() -> void:
	## Calling _apply_component_data twice does not add duplicate authority markers.
	assert_bool(false).is_true()  # STUB: implement after Plan 02
