extends GdUnitTestSuite

const CommandBuffer = preload("res://addons/gecs/ecs/command_buffer.gd")

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	# Don't call purge - entities are auto_free'd by gdUnit4
	pass


func test_command_buffer_initialization():
	var cmd = CommandBuffer.new(world)
	assert_bool(cmd.is_empty()).is_true()
	assert_int(cmd.size()).is_equal(0)


func test_add_component_command():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)

	# Queue command
	cmd.add_component(entity, C_TestB.new())
	assert_int(cmd.size()).is_equal(1)

	# Component should not be added yet
	assert_bool(entity.has_component(C_TestB)).is_false()

	# Execute commands
	cmd.execute()

	# Component should now be added
	assert_bool(entity.has_component(C_TestB)).is_true()
	assert_bool(cmd.is_empty()).is_true()


func test_remove_component_command():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)
	entity.add_component(C_TestB.new())

	# Queue command
	cmd.remove_component(entity, C_TestB)

	# Component should still exist
	assert_bool(entity.has_component(C_TestB)).is_true()

	# Execute commands
	cmd.execute()

	# Component should now be removed
	assert_bool(entity.has_component(C_TestB)).is_false()


func test_add_components_batch():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)

	# Queue batch add
	cmd.add_components(entity, [C_TestB.new(), C_TestC.new()])

	# Execute commands
	cmd.execute()

	# Both components should be added
	assert_bool(entity.has_component(C_TestB)).is_true()
	assert_bool(entity.has_component(C_TestC)).is_true()


func test_remove_components_batch():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)
	entity.add_component(C_TestB.new())
	entity.add_component(C_TestC.new())

	# Queue batch remove
	cmd.remove_components(entity, [C_TestB, C_TestC])

	# Execute commands
	cmd.execute()

	# Both components should be removed
	assert_bool(entity.has_component(C_TestB)).is_false()
	assert_bool(entity.has_component(C_TestC)).is_false()


func test_add_entity_command():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())

	# Queue command
	cmd.add_entity(entity)

	# Entity should not be in world yet
	assert_bool(world.entities.has(entity)).is_false()

	# Execute commands
	cmd.execute()

	# Entity should now be in world
	assert_bool(world.entities.has(entity)).is_true()


func test_remove_entity_command():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)

	# Queue command
	cmd.remove_entity(entity)

	# Entity should still be in world
	assert_bool(world.entities.has(entity)).is_true()

	# Execute commands
	cmd.execute()

	# Entity should now be removed from world
	assert_bool(world.entities.has(entity)).is_false()


func test_add_relationship_command():
	var cmd = CommandBuffer.new(world)
	var entity1 = auto_free(TestA.new())
	var entity2 = auto_free(TestA.new())
	world.add_entity(entity1)
	world.add_entity(entity2)

	var relationship = Relationship.new(C_TestA.new(), entity2)

	# Queue command
	cmd.add_relationship(entity1, relationship)

	# Relationship should not exist yet
	assert_bool(entity1.has_relationship(relationship)).is_false()

	# Execute commands
	cmd.execute()

	# Relationship should now exist
	assert_bool(entity1.has_relationship(relationship)).is_true()


func test_remove_relationship_command():
	var cmd = CommandBuffer.new(world)
	var entity1 = auto_free(TestA.new())
	var entity2 = auto_free(TestA.new())
	world.add_entity(entity1)
	world.add_entity(entity2)

	var relationship = Relationship.new(C_TestA.new(), entity2)
	entity1.add_relationship(relationship)

	# Queue command
	cmd.remove_relationship(entity1, relationship)

	# Relationship should still exist
	assert_bool(entity1.has_relationship(relationship)).is_true()

	# Execute commands
	cmd.execute()

	# Relationship should now be removed
	assert_bool(entity1.has_relationship(relationship)).is_false()


func test_custom_command():
	var cmd = CommandBuffer.new(world)
	var test_value = [0]  # Use array for pass-by-reference

	# Queue custom command
	cmd.add_custom(func(): test_value[0] = 42)

	# Value should not be changed yet
	assert_int(test_value[0]).is_equal(0)

	# Execute commands
	cmd.execute()

	# Value should now be changed
	assert_int(test_value[0]).is_equal(42)


func test_batched_execution():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)

	# Queue multiple operations on the same entity
	cmd.add_component(entity, C_TestB.new())
	cmd.add_component(entity, C_TestC.new())
	cmd.remove_component(entity, C_TestA)

	# Execute commands
	cmd.execute()

	# All operations should have been batched and executed
	assert_bool(entity.has_component(C_TestB)).is_true()
	assert_bool(entity.has_component(C_TestC)).is_true()
	assert_bool(entity.has_component(C_TestA)).is_false()


func test_skip_freed_entities():
	var cmd = CommandBuffer.new(world)
	var entity = TestA.new()  # Don't auto_free so we can manually free
	world.add_entity(entity)

	# Queue command
	cmd.add_component(entity, C_TestB.new())

	# Free the entity
	entity.free()

	# Execute should not crash
	cmd.execute()

	# Command queue should be empty
	assert_bool(cmd.is_empty()).is_true()


func test_clear_commands():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)

	# Queue commands
	cmd.add_component(entity, C_TestB.new())
	cmd.remove_entity(entity)

	assert_int(cmd.size()).is_equal(2)

	# Clear without executing
	cmd.clear()

	# Queue should be empty
	assert_bool(cmd.is_empty()).is_true()

	# Commands should not have been executed
	assert_bool(entity.has_component(C_TestB)).is_false()
	assert_bool(world.entities.has(entity)).is_true()


func test_statistics_tracking():
	var cmd = CommandBuffer.new(world)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)

	# Queue commands
	cmd.add_component(entity, C_TestB.new())
	cmd.add_component(entity, C_TestC.new())

	# Check stats before execution
	var stats_before = cmd.get_stats()
	assert_int(stats_before["commands_queued"]).is_equal(2)
	assert_int(stats_before["commands_executed"]).is_equal(0)

	# Execute
	cmd.execute()

	# Check stats after execution
	var stats_after = cmd.get_stats()
	assert_int(stats_after["commands_executed"]).is_equal(2)


func test_cache_invalidation_optimization():
	var cmd = CommandBuffer.new(world)
	var entities = []

	# Create multiple entities
	for i in range(10):
		var entity = auto_free(TestA.new())
		world.add_entity(entity)
		entities.append(entity)

	# Track initial cache invalidation count
	var initial_invalidations = world._cache_invalidation_count

	# Queue multiple component additions
	for entity in entities:
		cmd.add_component(entity, C_TestB.new())

	# Execute (should only invalidate cache once)
	cmd.execute()

	# Check that cache was only invalidated once
	var final_invalidations = world._cache_invalidation_count
	assert_int(final_invalidations - initial_invalidations).is_equal(1)


func test_forward_iteration_safety():
	var cmd = CommandBuffer.new(world)
	var entities = []

	# Create entities
	for i in range(10):
		var entity = auto_free(TestA.new())
		world.add_entity(entity)
		entities.append(entity)

	# Use forward iteration (the whole point of CommandBuffer!)
	for entity in entities:
		cmd.remove_entity(entity)

	# Execute
	cmd.execute()

	# All entities should be removed
	for entity in entities:
		assert_bool(world.entities.has(entity)).is_false()


func test_mixed_operations():
	var cmd = CommandBuffer.new(world)
	var entity1 = auto_free(TestA.new())
	var entity2 = auto_free(TestB.new())
	var entity3 = auto_free(TestC.new())

	world.add_entity(entity1)
	world.add_entity(entity2)

	# Mix of different operations
	cmd.add_component(entity1, C_TestB.new())
	cmd.add_entity(entity3)
	cmd.remove_entity(entity2)
	cmd.add_relationship(entity1, Relationship.new(C_TestA.new(), entity3))

	# Execute all
	cmd.execute()

	# Verify results
	assert_bool(entity1.has_component(C_TestB)).is_true()
	assert_bool(world.entities.has(entity3)).is_true()
	assert_bool(world.entities.has(entity2)).is_false()
	assert_bool(entity1.has_relationship(Relationship.new(C_TestA.new(), entity3))).is_true()
