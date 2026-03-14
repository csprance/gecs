extends GdUnitTestSuite

## Test suite for NativeSyncHandler (SYNC-04).
## Validates MultiplayerSynchronizer lifecycle: setup, cleanup, authority, idempotency.


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
var handler: NativeSyncHandler


func before_test() -> void:
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)
	# NativeSyncHandler only uses _ns._world for refresh_synchronizer_visibility.
	# For setup_native_sync / cleanup_native_sync, _ns is not accessed.
	handler = NativeSyncHandler.new(mock_ns)


func after_test() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await get_tree().process_frame


# ============================================================================
# TESTS — SYNC-04
# ============================================================================


func test_native_sync_creates_net_sync_child() -> void:
	## Entity with CN_NativeSync + CN_NetworkIdentity gets a "_NetSync" child after setup.
	var entity = Entity.new()
	add_child(entity)

	var native_sync = CN_NativeSync.new()
	native_sync.sync_position = false  # avoid Node path issues in headless test
	native_sync.sync_rotation = false
	entity.add_component(native_sync)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 1
	entity.add_component(net_id)

	handler.setup_native_sync(entity)

	assert_that(entity.get_node_or_null("_NetSync")).is_not_null()


func test_no_net_sync_without_cn_native_sync() -> void:
	## Entity without CN_NativeSync does NOT get a "_NetSync" child node.
	var entity = Entity.new()
	add_child(entity)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 1
	entity.add_component(net_id)

	handler.setup_native_sync(entity)

	assert_that(entity.get_node_or_null("_NetSync")).is_null()


func test_cleanup_removes_net_sync_node() -> void:
	## NativeSyncHandler.cleanup_native_sync() removes the "_NetSync" child node.
	var entity = Entity.new()
	add_child(entity)

	var native_sync = CN_NativeSync.new()
	native_sync.sync_position = false
	native_sync.sync_rotation = false
	entity.add_component(native_sync)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 1
	entity.add_component(net_id)

	handler.setup_native_sync(entity)
	assert_that(entity.get_node_or_null("_NetSync")).is_not_null()

	handler.cleanup_native_sync(entity)
	assert_that(entity.get_node_or_null("_NetSync")).is_null()


func test_authority_set_to_1_for_server_owned() -> void:
	## When net_id.peer_id == 0 (server-owned), synchronizer authority is 1 (Godot server).
	var entity = Entity.new()
	add_child(entity)

	var native_sync = CN_NativeSync.new()
	native_sync.sync_position = false
	native_sync.sync_rotation = false
	entity.add_component(native_sync)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 0  # server-owned
	entity.add_component(net_id)

	handler.setup_native_sync(entity)

	var synchronizer = entity.get_node_or_null("_NetSync") as MultiplayerSynchronizer
	assert_int(synchronizer.get_multiplayer_authority()).is_equal(1)


func test_setup_idempotent() -> void:
	## Calling setup_native_sync() twice does NOT create a second "_NetSync" node.
	var entity = Entity.new()
	add_child(entity)

	var native_sync = CN_NativeSync.new()
	native_sync.sync_position = false
	native_sync.sync_rotation = false
	entity.add_component(native_sync)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 2
	entity.add_component(net_id)

	handler.setup_native_sync(entity)
	handler.setup_native_sync(entity)  # second call must be a no-op

	# Entity should only have 1 child (the single "_NetSync" synchronizer)
	# Count children that are MultiplayerSynchronizer
	var sync_count = 0
	for child in entity.get_children():
		if child is MultiplayerSynchronizer:
			sync_count += 1
	assert_int(sync_count).is_equal(1)
