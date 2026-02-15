extends GdUnitTestSuite

## Test suite for SyncSpawnHandler
## Tests entity spawn serialization, scene path validation, world state
## serialization, and despawn session validation.

const SyncSpawnHandler = preload("res://addons/gecs_network/sync_spawn_handler.gd")
const SyncRelationshipHandler = preload("res://addons/gecs_network/sync_relationship_handler.gd")

var world: World
var handler: RefCounted  # SyncSpawnHandler
var mock_ns: RefCounted  # Mock NetworkSync

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
	var sync_config: SyncConfig
	var net_adapter: MockNetAdapter
	var debug_logging: bool = false
	var _relationship_handler: RefCounted

	func _init(w: World) -> void:
		_world = w
		sync_config = SyncConfig.new()
		sync_config.sync_relationships = true
		net_adapter = MockNetAdapter.new()

	func _find_component_by_type(entity: Entity, comp_type: String):
		for comp_path in entity.components.keys():
			var comp = entity.components[comp_path]
			var script = comp.get_script()
			if script == null:
				continue
			var name_str = script.get_global_name()
			if name_str == "":
				name_str = script.resource_path.get_file().get_basename()
			if name_str == comp_type:
				return comp
		return null


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================


func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)
	mock_ns._relationship_handler = SyncRelationshipHandler.new(mock_ns)
	handler = SyncSpawnHandler.new(mock_ns)


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
# SERIALIZE ENTITY SPAWN
# ============================================================================


func test_serialize_entity_spawn_includes_id():
	var entity = Entity.new()
	entity.id = "test-entity-1"
	entity.name = "TestEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var data = handler.serialize_entity_spawn(entity)
	assert_str(data["id"]).is_equal("test-entity-1")


func test_serialize_entity_spawn_includes_name():
	var entity = Entity.new()
	entity.id = "test-entity-1"
	entity.name = "TestEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var data = handler.serialize_entity_spawn(entity)
	assert_str(data["name"]).is_equal("TestEntity")


func test_serialize_entity_spawn_includes_session_id():
	var entity = Entity.new()
	entity.id = "test-entity-1"
	entity.name = "TestEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var data = handler.serialize_entity_spawn(entity)
	assert_int(data["session_id"]).is_equal(42)


func test_serialize_entity_spawn_includes_components():
	var entity = Entity.new()
	entity.id = "test-entity-1"
	entity.name = "TestEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	entity.add_component(C_TestA.new(99))
	world.add_entity(entity)

	var data = handler.serialize_entity_spawn(entity)
	assert_bool(data["components"].has("CN_NetworkIdentity")).is_true()
	assert_bool(data["components"].has("C_TestA")).is_true()


func test_serialize_entity_spawn_includes_script_paths():
	var entity = Entity.new()
	entity.id = "test-entity-1"
	entity.name = "TestEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var data = handler.serialize_entity_spawn(entity)
	assert_bool(data.has("script_paths")).is_true()
	assert_bool(data["script_paths"].has("CN_NetworkIdentity")).is_true()


func test_serialize_entity_spawn_skips_model_ready_component():
	mock_ns.sync_config.model_ready_component = "C_TestA"
	var entity = Entity.new()
	entity.id = "test-entity-1"
	entity.name = "TestEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	entity.add_component(C_TestA.new())
	world.add_entity(entity)

	var data = handler.serialize_entity_spawn(entity)
	assert_bool(data["components"].has("C_TestA")).is_false()


func test_serialize_entity_spawn_includes_relationships():
	mock_ns.sync_config.sync_relationships = true
	var entity = Entity.new()
	entity.id = "source-1"
	entity.name = "Source"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var target = Entity.new()
	target.id = "target-1"
	target.name = "Target"
	world.add_entity(target)

	entity.add_relationship(Relationship.new(C_TestA.new(), target))

	var data = handler.serialize_entity_spawn(entity)
	assert_bool(data.has("relationships")).is_true()
	assert_int(data["relationships"].size()).is_equal(1)


# ============================================================================
# SCENE PATH VALIDATION
# ============================================================================


func test_validate_empty_scene_path():
	assert_bool(handler.validate_entity_spawn("")).is_true()


func test_validate_invalid_scheme():
	assert_bool(handler.validate_entity_spawn("invalid://path.tscn")).is_false()


func test_validate_nonexistent_scene():
	assert_bool(handler.validate_entity_spawn("res://nonexistent_scene_xyz.tscn")).is_false()


# ============================================================================
# WORLD STATE SERIALIZATION
# ============================================================================


func test_serialize_world_state_includes_session_id():
	var state = handler.serialize_world_state()
	assert_int(state["session_id"]).is_equal(42)


func test_serialize_world_state_only_includes_networked_entities():
	# Entity with CN_NetworkIdentity
	var networked = Entity.new()
	networked.id = "networked-1"
	networked.name = "NetworkedEntity"
	networked.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(networked)

	# Entity without CN_NetworkIdentity
	var local = Entity.new()
	local.id = "local-1"
	local.name = "LocalEntity"
	local.add_component(C_TestA.new())
	world.add_entity(local)

	var state = handler.serialize_world_state()
	assert_int(state["entities"].size()).is_equal(1)
	assert_str(state["entities"][0]["id"]).is_equal("networked-1")


func test_serialize_world_state_empty_world():
	var state = handler.serialize_world_state()
	assert_int(state["entities"].size()).is_equal(0)


# ============================================================================
# DESPAWN SESSION VALIDATION
# ============================================================================


func test_despawn_with_correct_session_removes_entity():
	var entity = Entity.new()
	entity.id = "despawn-1"
	entity.name = "DespawnEntity"
	world.add_entity(entity)

	handler.handle_despawn_entity("despawn-1", 42)
	# Entity should be removed from world
	assert_bool(world.entity_id_registry.has("despawn-1")).is_false()


func test_despawn_with_wrong_session_does_not_remove():
	var entity = Entity.new()
	entity.id = "despawn-2"
	entity.name = "DespawnEntity2"
	world.add_entity(entity)

	handler.handle_despawn_entity("despawn-2", 999)
	# Entity should still exist
	assert_bool(world.entity_id_registry.has("despawn-2")).is_true()


func test_despawn_nonexistent_entity_does_not_crash():
	# Should not crash when entity doesn't exist
	handler.handle_despawn_entity("nonexistent-id", 42)
	# Just verifying no crash occurred
	assert_bool(true).is_true()
