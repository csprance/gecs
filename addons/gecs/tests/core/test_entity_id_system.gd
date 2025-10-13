extends GdUnitTestSuite

## Test suite for the Entity ID system functionality
## Tests auto-generation, custom IDs, singleton behavior, and world-level enforcement

var world: World

func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

func after_test():
	if is_instance_valid(world):
		world.queue_free()
	await await_idle_frame()

func test_entity_id_auto_generation():
	# Test that entities auto-generate IDs in _enter_tree
	var entity = Entity.new()
	entity.name = "TestEntity"

	# ID should be empty before entering tree
	assert_str(entity.id).is_empty()

	# Add to tree - triggers _enter_tree and ID generation
	world.add_entity(entity)

	# ID should now be auto-generated
	assert_str(entity.id).is_not_empty()
	assert_bool(entity.id.length() > 0).is_true()

	# Should not change ID on subsequent checks
	var first_id = entity.id
	var second_id = entity.id
	assert_str(second_id).is_equal(first_id)

func test_entity_custom_id():
	# Test custom ID functionality for singleton entities
	var entity = Entity.new()
	entity.name = "SingletonEntity"

	# Set custom ID before adding to world
	entity.id = "singleton_player"
	assert_str(entity.id).is_equal("singleton_player")

	# Add to world - should preserve custom ID
	world.add_entity(entity)
	assert_str(entity.id).is_equal("singleton_player")

	# Custom ID should not change on subsequent access
	var same_id = entity.id
	assert_str(same_id).is_equal("singleton_player")

func test_world_id_tracking():
	# Test that World tracks IDs and provides lookup functionality
	var entity1 = Entity.new()
	entity1.name = "Entity1"
	entity1.id = "test_id_1"

	var entity2 = Entity.new()
	entity2.name = "Entity2"
	entity2.id = "test_id_2"

	# Add entities to world
	world.add_entity(entity1)
	world.add_entity(entity2)

	# Test lookup by ID
	assert_object(world.get_entity_by_id("test_id_1")).is_same(entity1)
	assert_object(world.get_entity_by_id("test_id_2")).is_same(entity2)
	assert_object(world.get_entity_by_id("nonexistent")).is_null()

	# Test has_entity_with_id
	assert_bool(world.has_entity_with_id("test_id_1")).is_true()
	assert_bool(world.has_entity_with_id("test_id_2")).is_true()
	assert_bool(world.has_entity_with_id("nonexistent")).is_false()

func test_world_id_replacement():
	# Test singleton behavior - entities with same ID replace existing ones
	# Create first entity with custom ID
	var entity1 = Entity.new()
	entity1.name = "FirstEntity"
	entity1.id = "singleton_player"
	var comp1 = C_TestA.new()
	comp1.value = 100
	entity1.add_component(comp1)
	world.add_entity(entity1)

	# Verify it's in the world
	assert_int(world.entities.size()).is_equal(1)
	assert_object(world.get_entity_by_id("singleton_player")).is_same(entity1)

	# Create second entity with same ID
	var entity2 = Entity.new()
	entity2.name = "ReplacementEntity"
	entity2.id = "singleton_player"
	var comp2 = C_TestA.new()
	comp2.value = 200
	entity2.add_component(comp2)

	# Add to world - should replace first entity
	world.add_entity(entity2)

	# Should still have only one entity
	assert_int(world.entities.size()).is_equal(1)
	# Should be the new entity
	var found_entity = world.get_entity_by_id("singleton_player")
	assert_object(found_entity).is_same(entity2)
	assert_str(found_entity.name).is_equal("ReplacementEntity")

	# Verify component value is from new entity
	var comp = found_entity.get_component(C_TestA) as C_TestA
	assert_int(comp.value).is_equal(200)

func test_auto_generated_id_tracking():
	# Test that auto-generated IDs are also tracked by the world
	var entity = Entity.new()
	entity.name = "AutoIDEntity"
	# Don't set custom ID - let it auto-generate

	world.add_entity(entity)

	# Should have auto-generated ID
	assert_str(entity.id).is_not_empty()

	# Should be trackable by ID
	assert_object(world.get_entity_by_id(entity.id)).is_same(entity)
	assert_bool(world.has_entity_with_id(entity.id)).is_true()

func test_id_generation_format():
	# Test that generated IDs follow expected GUID format
	var entity = Entity.new()

	# Add to tree to trigger ID generation
	world.add_entity(entity)

	var id = entity.id
	assert_str(id).is_not_empty()
	assert_bool(id.contains("-")).is_true()

	var parts = id.split("-")
	assert_int(parts.size()).is_equal(5)

	# All parts should be valid hex strings
	for part in parts:
		assert_bool(part.is_valid_hex_number()).is_true()

func test_id_uniqueness():
	# Test that multiple entities get unique IDs
	var ids = {}
	var entities = []

	# Generate 100 entities with auto IDs
	for i in range(100):
		var entity = Entity.new()
		entity.name = "Entity%d" % i
		world.add_entity(entity)
		entities.append(entity)

		# Should not have seen this ID before
		assert_bool(ids.has(entity.id)).is_false()
		ids[entity.id] = true

	# All IDs should be unique
	assert_int(ids.size()).is_equal(100)

func test_remove_entity_clears_id_registry():
	# Test that removing entities clears them from ID registry
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.id = "test_remove_id"

	world.add_entity(entity)
	assert_bool(world.has_entity_with_id("test_remove_id")).is_true()

	world.remove_entity(entity)
	assert_bool(world.has_entity_with_id("test_remove_id")).is_false()
	assert_object(world.get_entity_by_id("test_remove_id")).is_null()

func test_id_system_comprehensive_demo():
	# Comprehensive test demonstrating all ID system features
	# Test 1: Auto ID generation
	var auto_entity = Entity.new()
	auto_entity.name = "AutoIDEntity"
	world.add_entity(auto_entity)

	var generated_id = auto_entity.id
	assert_str(generated_id).is_not_empty() # Should auto-generate
	assert_bool(generated_id.contains("-")).is_true() # Should have correct GUID format

	# Should still have the same ID
	assert_str(auto_entity.id).is_equal(generated_id)

	# Test 2: Custom ID singleton behavior
	var player1 = Entity.new()
	player1.name = "Player1"
	player1.id = "singleton_player"
	var comp1 = C_TestA.new()
	comp1.value = 100
	player1.add_component(comp1)
	world.add_entity(player1)

	assert_int(world.entities.size()).is_equal(2) # auto_entity + player1
	assert_object(world.get_entity_by_id("singleton_player")).is_same(player1)

	# Add second entity with same ID - should replace first
	var player2 = Entity.new()
	player2.name = "Player2"
	player2.id = "singleton_player"
	var comp2 = C_TestA.new()
	comp2.value = 200
	player2.add_component(comp2)
	world.add_entity(player2)

	assert_int(world.entities.size()).is_equal(2) # Should still be 2 (replacement occurred)
	var found_entity = world.get_entity_by_id("singleton_player")
	assert_object(found_entity).is_same(player2) # Should be the new entity
	assert_str(found_entity.name).is_equal("Player2")

	var found_comp = found_entity.get_component(C_TestA) as C_TestA
	assert_int(found_comp.value).is_equal(200) # Should have new entity's data

	# Test 3: Multiple entity tracking
	var tracked_entities = []
	for i in range(3):
		var entity = Entity.new()
		entity.name = "TrackedEntity%d" % i
		entity.id = "tracked_%d" % i
		tracked_entities.append(entity)
		world.add_entity(entity)

	# Verify all are tracked
	for i in range(3):
		var id = "tracked_%d" % i
		assert_bool(world.has_entity_with_id(id)).is_true()
		assert_object(world.get_entity_by_id(id)).is_same(tracked_entities[i])

	# Test 4: ID registry cleanup on removal
	world.remove_entity(tracked_entities[1])
	assert_bool(world.has_entity_with_id("tracked_1")).is_false()
	assert_object(world.get_entity_by_id("tracked_1")).is_null()
	# Others should still exist
	assert_bool(world.has_entity_with_id("tracked_0")).is_true()
	assert_bool(world.has_entity_with_id("tracked_2")).is_true()
