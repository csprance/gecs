extends GdUnitTestSuite

## Test suite for SyncStateHandler
## Tests auto-marker assignment, network ID generation, and peer validation.

const SyncStateHandler = preload("res://addons/gecs_network/sync_state_handler.gd")
const SyncRelationshipHandler = preload("res://addons/gecs_network/sync_relationship_handler.gd")

var world: World
var handler: RefCounted  # SyncStateHandler
var mock_ns: RefCounted  # Mock NetworkSync

# ============================================================================
# MOCK OBJECTS
# ============================================================================


class MockNetAdapter:
	extends NetAdapter

	var _is_server: bool = false
	var _my_peer_id: int = 1

	func is_server() -> bool:
		return _is_server

	func get_my_peer_id() -> int:
		return _my_peer_id

	# NOTE: Returns empty peer list — _is_valid_peer() will only pass for
	# peer IDs 0, 1, and _my_peer_id. Extend this if adding authority
	# transfer tests that involve connected peers.
	func get_connected_peers() -> Array[int]:
		return []

	func _has_multiplayer() -> bool:
		return true


class MockNetworkSync:
	extends RefCounted

	var _world: World
	var _applying_network_data: bool = false
	var _game_session_id: int = 0
	var _spawn_counter: int = 0
	var sync_config: SyncConfig
	var net_adapter: MockNetAdapter
	var debug_logging: bool = false
	var _relationship_handler: RefCounted

	func _init(w: World) -> void:
		_world = w
		sync_config = SyncConfig.new()
		net_adapter = MockNetAdapter.new()


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================


func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)
	# Create relationship handler for serialize_entity_full
	mock_ns._relationship_handler = SyncRelationshipHandler.new(mock_ns)
	handler = SyncStateHandler.new(mock_ns)


func after_test():
	handler = null
	mock_ns = null
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	world = null


# ============================================================================
# AUTO-MARKER ASSIGNMENT: SERVER PERSPECTIVE
# ============================================================================


func test_server_owned_entity_on_server_gets_local_authority():
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._my_peer_id = 1

	var entity = Entity.new()
	entity.name = "Enemy"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	handler.auto_assign_markers(entity)

	assert_bool(entity.has_component(CN_LocalAuthority)).is_true()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_false()
	assert_bool(entity.has_component(CN_ServerOwned)).is_true()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_true()


func test_host_player_entity_on_server_gets_local_authority():
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._my_peer_id = 1

	var entity = Entity.new()
	entity.name = "HostPlayer"
	entity.add_component(CN_NetworkIdentity.new(1))
	world.add_entity(entity)

	handler.auto_assign_markers(entity)

	assert_bool(entity.has_component(CN_LocalAuthority)).is_true()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_false()
	# peer_id=1 is server-owned (is_server_owned returns true for 0 and 1)
	assert_bool(entity.has_component(CN_ServerOwned)).is_true()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_true()


func test_client_entity_on_server_gets_remote_entity():
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._my_peer_id = 1

	var entity = Entity.new()
	entity.name = "ClientPlayer"
	entity.add_component(CN_NetworkIdentity.new(2))
	world.add_entity(entity)

	handler.auto_assign_markers(entity)

	assert_bool(entity.has_component(CN_LocalAuthority)).is_false()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_true()
	# peer_id=2 is not server-owned
	assert_bool(entity.has_component(CN_ServerOwned)).is_false()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_false()


# ============================================================================
# AUTO-MARKER ASSIGNMENT: CLIENT PERSPECTIVE
# ============================================================================


func test_server_owned_entity_on_client_gets_remote_entity():
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2

	var entity = Entity.new()
	entity.name = "Enemy"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	handler.auto_assign_markers(entity)

	assert_bool(entity.has_component(CN_LocalAuthority)).is_false()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_true()
	assert_bool(entity.has_component(CN_ServerOwned)).is_true()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_true()


func test_own_entity_on_client_gets_local_authority():
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2

	var entity = Entity.new()
	entity.name = "MyPlayer"
	entity.add_component(CN_NetworkIdentity.new(2))
	world.add_entity(entity)

	handler.auto_assign_markers(entity)

	assert_bool(entity.has_component(CN_LocalAuthority)).is_true()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_false()


func test_other_client_entity_on_client_gets_remote_entity():
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2

	var entity = Entity.new()
	entity.name = "OtherPlayer"
	entity.add_component(CN_NetworkIdentity.new(3))
	world.add_entity(entity)

	handler.auto_assign_markers(entity)

	assert_bool(entity.has_component(CN_LocalAuthority)).is_false()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_true()


# ============================================================================
# AUTO-MARKER EDGE CASES
# ============================================================================


func test_entity_without_network_identity_gets_no_markers():
	var entity = Entity.new()
	entity.name = "LocalOnly"
	world.add_entity(entity)

	handler.auto_assign_markers(entity)

	assert_bool(entity.has_component(CN_LocalAuthority)).is_false()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_false()
	assert_bool(entity.has_component(CN_ServerOwned)).is_false()
	assert_bool(entity.has_component(CN_ServerAuthority)).is_false()


func test_calling_twice_replaces_old_markers():
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._my_peer_id = 1

	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	handler.auto_assign_markers(entity)
	assert_bool(entity.has_component(CN_LocalAuthority)).is_true()

	# Now simulate becoming a client perspective
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2

	handler.auto_assign_markers(entity)
	# Should now have CN_RemoteEntity instead of CN_LocalAuthority
	assert_bool(entity.has_component(CN_LocalAuthority)).is_false()
	assert_bool(entity.has_component(CN_RemoteEntity)).is_true()


# ============================================================================
# NETWORK ID GENERATION
# ============================================================================


func test_deterministic_id_format():
	var id = handler.generate_network_id(0, true)
	# Format: "{peer_id}_{timestamp}_{counter}"
	var parts = id.split("_")
	assert_int(parts.size()).is_equal(3)
	assert_str(parts[0]).is_equal("0")


func test_deterministic_id_counter_increments():
	var id1 = handler.generate_network_id(0, true)
	var id2 = handler.generate_network_id(0, true)
	# Counter should be different
	var counter1 = id1.split("_")[2].to_int()
	var counter2 = id2.split("_")[2].to_int()
	assert_int(counter2).is_equal(counter1 + 1)


func test_deterministic_id_includes_peer_id():
	var id = handler.generate_network_id(5, true)
	var parts = id.split("_")
	assert_str(parts[0]).is_equal("5")


# ============================================================================
# PEER VALIDATION
# ============================================================================


func test_is_valid_peer_zero():
	assert_bool(handler._is_valid_peer(0)).is_true()


func test_is_valid_peer_one():
	assert_bool(handler._is_valid_peer(1)).is_true()
