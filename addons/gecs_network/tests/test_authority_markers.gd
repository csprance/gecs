extends GdUnitTestSuite

## Tests for LIFE-05 authority marker injection in SpawnManager._inject_authority_markers().
## All 5 tests verify the remove-then-add idempotency pattern and correct authority assignment.


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
# AUTHORITY MARKER INJECTION TESTS
# ============================================================================


func test_local_authority_added_for_local_peer() -> void:
	## CN_LocalAuthority is added when net_id.peer_id == local peer id (peer 2 on a client).
	## CN_ServerAuthority is NOT added since peer_id=2 is not server-owned.
	mock_ns.net_adapter._my_peer_id = 2
	mock_ns.net_adapter._is_server = false

	var entity = Entity.new()
	add_child(entity)
	ECS.world.add_entity(entity)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 2
	entity.add_component(net_id)

	manager._apply_component_data(entity, {})

	assert_bool(entity.has_component(CN_LocalAuthority)).is_true()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_false()


func test_server_authority_added_for_server_owned() -> void:
	## CN_ServerAuthority is added when net_id.peer_id == 0 (server-owned entity).
	## This applies on all peers — clients also see server-owned entities get CN_ServerAuthority.
	mock_ns.net_adapter._my_peer_id = 2
	mock_ns.net_adapter._is_server = false

	var entity = Entity.new()
	add_child(entity)
	ECS.world.add_entity(entity)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 0  # server-owned
	entity.add_component(net_id)

	manager._apply_component_data(entity, {})

	assert_bool(entity.has_component(CN_ServerAuthority)).is_true()


func test_server_gets_local_authority_on_server_owned() -> void:
	## Server peer (is_server=true) gets CN_LocalAuthority on server-owned entities (peer_id=0).
	## Server also gets CN_ServerAuthority since peer_id=0 is server-owned.
	mock_ns.net_adapter._my_peer_id = 1
	mock_ns.net_adapter._is_server = true

	var entity = Entity.new()
	add_child(entity)
	ECS.world.add_entity(entity)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 0  # server-owned
	entity.add_component(net_id)

	manager._apply_component_data(entity, {})

	assert_bool(entity.has_component(CN_LocalAuthority)).is_true()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_true()


func test_client_no_local_authority_on_other_peer() -> void:
	## Client (peer_id=2) does NOT get CN_LocalAuthority for entity owned by a different peer (peer_id=3).
	## CN_ServerAuthority also absent since peer_id=3 is not server-owned.
	mock_ns.net_adapter._my_peer_id = 2
	mock_ns.net_adapter._is_server = false

	var entity = Entity.new()
	add_child(entity)
	ECS.world.add_entity(entity)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 3  # different client's entity
	entity.add_component(net_id)

	manager._apply_component_data(entity, {})

	assert_bool(entity.has_component(CN_LocalAuthority)).is_false()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_false()


func test_marker_injection_idempotent() -> void:
	## Calling _apply_component_data twice on the same entity does not add duplicate markers.
	## The remove-then-add pattern ensures exactly one of each marker exists.
	mock_ns.net_adapter._my_peer_id = 2
	mock_ns.net_adapter._is_server = false

	var entity = Entity.new()
	add_child(entity)
	ECS.world.add_entity(entity)

	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 2  # local peer entity
	entity.add_component(net_id)

	# Call twice to test idempotency
	manager._apply_component_data(entity, {})
	manager._apply_component_data(entity, {})

	# Count CN_LocalAuthority components — should be exactly 1, not 2
	var local_auth_count = 0
	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		if comp is CN_LocalAuthority:
			local_auth_count += 1

	assert_int(local_auth_count).is_equal(1)
