extends GdUnitTestSuite

## Test suite for SyncRelationshipHandler
## Tests round-trip serialization/deserialization of relationship creation recipes,
## deferred Entity target resolution, sync loop prevention, and authority filtering.

const SyncRelationshipHandler = preload("res://addons/gecs_network/sync_relationship_handler.gd")

var world: World
var handler: RefCounted  # SyncRelationshipHandler
var mock_ns: RefCounted  # Mock NetworkSync

# ============================================================================
# MOCK OBJECTS
# ============================================================================


## Minimal mock for NetworkSync - provides only what the handler needs
class MockNetworkSync:
	extends RefCounted
	var _world: World
	var _applying_network_data: bool = false
	var _game_session_id: int = 0
	var sync_config: SyncConfig
	var net_adapter: NetAdapter
	var debug_logging: bool = false

	# Track RPC calls for verification
	var last_rpc_method: String = ""
	var last_rpc_payload: Dictionary = {}

	func _init(w: World) -> void:
		_world = w
		sync_config = SyncConfig.new()
		sync_config.sync_relationships = true
		net_adapter = NetAdapter.new()

	func _sync_relationship_add(_payload: Dictionary) -> void:
		last_rpc_method = "_sync_relationship_add"
		last_rpc_payload = _payload


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================


func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)
	handler = SyncRelationshipHandler.new(mock_ns)


func after_test():
	handler = null
	mock_ns = null
	if is_instance_valid(world):
		# Remove all entities explicitly before freeing world to avoid
		# GdUnit4 orphan monitor "freed object" errors
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	world = null


# ============================================================================
# SERIALIZE / DESERIALIZE ROUND-TRIPS
# ============================================================================


func test_serialize_null_target():
	var rel = Relationship.new(C_TestA.new(), null)
	var recipe = handler.serialize_relationship(rel)

	assert_dict(recipe).is_not_empty()
	assert_str(recipe["tt"]).is_equal("N")
	assert_str(recipe["t"]).is_equal("")
	assert_str(recipe["r"]).contains("c_test_a.gd")


func test_roundtrip_null_target():
	var rel = Relationship.new(C_TestA.new(), null)
	var recipe = handler.serialize_relationship(rel)
	var restored = handler.deserialize_relationship(recipe)

	assert_object(restored).is_not_null()
	assert_object(restored.relation).is_not_null()
	assert_object(restored.relation).is_instanceof(C_TestA)
	assert_object(restored.target).is_null()


func test_serialize_entity_target():
	var entity = Entity.new()
	entity.name = "TargetEntity"
	entity.id = "target-123"
	world.add_entity(entity)

	var rel = Relationship.new(C_TestA.new(), entity)
	var recipe = handler.serialize_relationship(rel)

	assert_dict(recipe).is_not_empty()
	assert_str(recipe["tt"]).is_equal("E")
	assert_str(recipe["t"]).is_equal("target-123")


func test_roundtrip_entity_target():
	var entity = Entity.new()
	entity.name = "TargetEntity"
	entity.id = "target-123"
	world.add_entity(entity)

	var rel = Relationship.new(C_TestA.new(), entity)
	var recipe = handler.serialize_relationship(rel)
	var restored = handler.deserialize_relationship(recipe)

	assert_object(restored).is_not_null()
	assert_object(restored.target).is_not_null()
	assert_object(restored.target).is_instanceof(Entity)
	assert_str((restored.target as Entity).id).is_equal("target-123")


func test_roundtrip_component_target():
	var target_comp = C_TestB.new()
	var rel = Relationship.new(C_TestA.new(), target_comp)
	var recipe = handler.serialize_relationship(rel)

	assert_dict(recipe).is_not_empty()
	assert_str(recipe["tt"]).is_equal("C")
	assert_str(recipe["t"]).contains("c_test_b.gd")

	var restored = handler.deserialize_relationship(recipe)
	assert_object(restored).is_not_null()
	assert_object(restored.relation).is_instanceof(C_TestA)
	assert_object(restored.target).is_instanceof(C_TestB)


func test_roundtrip_script_target():
	var target_script = load("res://tests/gecs/components/c_test_a.gd")
	var rel = Relationship.new(C_TestB.new(), target_script)
	var recipe = handler.serialize_relationship(rel)

	assert_dict(recipe).is_not_empty()
	assert_str(recipe["tt"]).is_equal("S")
	assert_str(recipe["t"]).contains("c_test_a.gd")

	var restored = handler.deserialize_relationship(recipe)
	assert_object(restored).is_not_null()
	assert_object(restored.relation).is_instanceof(C_TestB)
	assert_object(restored.target).is_instanceof(Script)


func test_serialize_returns_empty_when_disabled():
	mock_ns.sync_config.sync_relationships = false
	var rel = Relationship.new(C_TestA.new(), null)
	var recipe = handler.serialize_relationship(rel)

	assert_dict(recipe).is_empty()


func test_serialize_returns_empty_for_null_relation():
	var rel = Relationship.new(null, null)
	var recipe = handler.serialize_relationship(rel)

	assert_dict(recipe).is_empty()


# ============================================================================
# ENTITY RELATIONSHIPS BATCH SERIALIZATION
# ============================================================================


func test_serialize_entity_relationships():
	var source = Entity.new()
	source.name = "Source"
	source.id = "source-1"
	world.add_entity(source)

	var target = Entity.new()
	target.name = "Target"
	target.id = "target-1"
	world.add_entity(target)

	source.add_relationship(Relationship.new(C_TestA.new(), target))
	source.add_relationship(Relationship.new(C_TestB.new(), null))

	var recipes = handler.serialize_entity_relationships(source)
	assert_int(recipes.size()).is_equal(2)

	# Check first recipe (C_TestA -> Entity target)
	assert_str(recipes[0]["tt"]).is_equal("E")
	assert_str(recipes[0]["t"]).is_equal("target-1")

	# Check second recipe (C_TestB -> null)
	assert_str(recipes[1]["tt"]).is_equal("N")


func test_apply_entity_relationships():
	var source = Entity.new()
	source.name = "Source"
	source.id = "source-1"
	world.add_entity(source)

	var target = Entity.new()
	target.name = "Target"
	target.id = "target-1"
	world.add_entity(target)

	var recipes: Array = [
		{"r": "res://tests/gecs/components/c_test_a.gd", "tt": "E", "t": "target-1"},
		{"r": "res://tests/gecs/components/c_test_b.gd", "tt": "N", "t": ""},
	]

	handler.apply_entity_relationships(source, recipes)

	assert_int(source.relationships.size()).is_equal(2)


# ============================================================================
# DEFERRED ENTITY TARGET RESOLUTION
# ============================================================================


func test_deferred_resolution_entity_target():
	var source = Entity.new()
	source.name = "Source"
	source.id = "source-1"
	world.add_entity(source)

	# Apply a recipe referencing an entity that doesn't exist yet
	var recipes: Array = [
		{"r": "res://tests/gecs/components/c_test_a.gd", "tt": "E", "t": "future-entity"},
	]

	handler.apply_entity_relationships(source, recipes)

	# Should have no relationships yet (target not resolved)
	assert_int(source.relationships.size()).is_equal(0)

	# Pending should have the queued recipe
	assert_bool(handler._pending_relationships.has("source-1")).is_true()

	# Now add the target entity to the world
	var target = Entity.new()
	target.name = "FutureTarget"
	target.id = "future-entity"
	world.add_entity(target)

	# Trigger deferred resolution (normally called by NetworkSync._on_entity_added)
	handler.try_resolve_pending(target)

	# Source should now have the relationship
	assert_int(source.relationships.size()).is_equal(1)
	assert_object(source.relationships[0].target).is_same(target)

	# Pending should be cleared
	assert_bool(handler._pending_relationships.has("source-1")).is_false()


func test_deferred_resolution_ignores_unrelated_entities():
	var source = Entity.new()
	source.name = "Source"
	source.id = "source-1"
	world.add_entity(source)

	# Queue a pending recipe for "future-entity"
	var recipes: Array = [
		{"r": "res://tests/gecs/components/c_test_a.gd", "tt": "E", "t": "future-entity"},
	]
	handler.apply_entity_relationships(source, recipes)

	# Add a different entity
	var unrelated = Entity.new()
	unrelated.name = "Unrelated"
	unrelated.id = "unrelated-entity"
	world.add_entity(unrelated)
	handler.try_resolve_pending(unrelated)

	# Should still be pending
	assert_int(source.relationships.size()).is_equal(0)
	assert_bool(handler._pending_relationships.has("source-1")).is_true()


# ============================================================================
# SYNC LOOP PREVENTION
# ============================================================================


func test_sync_loop_prevention_applying_flag():
	handler._applying_relationship_data = true

	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.id = "test-1"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var rel = Relationship.new(C_TestA.new(), null)
	handler.on_relationship_added(entity, rel)

	# Should not have made an RPC call due to sync loop guard
	assert_str(mock_ns.last_rpc_method).is_equal("")

	handler._applying_relationship_data = false


func test_sync_loop_prevention_network_data_flag():
	mock_ns._applying_network_data = true

	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.id = "test-1"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var rel = Relationship.new(C_TestA.new(), null)
	handler.on_relationship_added(entity, rel)

	# Should not have made an RPC call
	assert_str(mock_ns.last_rpc_method).is_equal("")

	mock_ns._applying_network_data = false


# ============================================================================
# RESET
# ============================================================================


func test_reset_clears_pending():
	var source = Entity.new()
	source.name = "Source"
	source.id = "source-1"
	world.add_entity(source)

	var recipes: Array = [
		{"r": "res://tests/gecs/components/c_test_a.gd", "tt": "E", "t": "missing-entity"},
	]
	handler.apply_entity_relationships(source, recipes)

	assert_bool(handler._pending_relationships.is_empty()).is_false()

	handler.reset()

	assert_bool(handler._pending_relationships.is_empty()).is_true()
	assert_bool(handler._applying_relationship_data).is_false()


# ============================================================================
# INVALID INPUT HANDLING
# ============================================================================


func test_deserialize_invalid_relation_path():
	var recipe = {"r": "invalid://path.gd", "tt": "N", "t": ""}
	var result = handler.deserialize_relationship(recipe)
	assert_object(result).is_null()


func test_deserialize_missing_relation_path():
	var recipe = {"r": "", "tt": "N", "t": ""}
	var result = handler.deserialize_relationship(recipe)
	assert_object(result).is_null()


func test_deserialize_unknown_target_type():
	var recipe = {"r": "res://tests/gecs/components/c_test_a.gd", "tt": "X", "t": ""}
	var result = handler.deserialize_relationship(recipe)
	assert_object(result).is_null()


func test_deserialize_entity_target_not_found():
	var recipe = {"r": "res://tests/gecs/components/c_test_a.gd", "tt": "E", "t": "nonexistent"}
	var result = handler.deserialize_relationship(recipe)
	assert_object(result).is_null()
