extends GdUnitTestSuite

## Wave 0 stubs for SYNC-04 NativeSyncHandler — MultiplayerSynchronizer node management.
## All tests fail until Plan 03 implements NativeSyncHandler and wires it into NetworkSync.


# ============================================================================
# MOCK OBJECTS
# ============================================================================


class MockNetAdapter:
	extends NetAdapter

	var _is_server: bool = true
	var _my_peer_id: int = 1

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
	## Forward-compatibility: will hold NativeSyncHandler instance once Plan 03 creates it.
	var _native_sync_handler = null

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


func before_test() -> void:
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await get_tree().process_frame


# ============================================================================
# WAVE 0 STUBS — go GREEN in Plan 03
# ============================================================================


func test_native_sync_creates_net_sync_child() -> void:
	## Entity with CN_NativeSync component gets a "_NetSync" MultiplayerSynchronizer child
	## node after NativeSyncHandler.setup_native_sync() is called.
	assert_bool(false).is_true()  # STUB: implement after Plan 03


func test_no_net_sync_without_cn_native_sync() -> void:
	## Entity without CN_NativeSync does NOT get a "_NetSync" child node.
	assert_bool(false).is_true()  # STUB: implement after Plan 03


func test_cleanup_removes_net_sync_node() -> void:
	## NativeSyncHandler.cleanup_native_sync() removes the "_NetSync" child node from the entity.
	assert_bool(false).is_true()  # STUB: implement after Plan 03


func test_authority_set_to_1_for_server_owned() -> void:
	## MultiplayerSynchronizer.get_multiplayer_authority() returns 1 when net_id.peer_id == 0
	## (server-owned entity). Server always has authority 1.
	assert_bool(false).is_true()  # STUB: implement after Plan 03


func test_setup_idempotent() -> void:
	## Calling setup_native_sync() twice on the same entity does not create a second "_NetSync" node.
	assert_bool(false).is_true()  # STUB: implement after Plan 03
