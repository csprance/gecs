extends GdUnitTestSuite

const CommandBuffer = preload("res://addons/gecs/ecs/command_buffer.gd")

var runner: GdUnitSceneRunner
var world: World


# Test system that uses PER_SYSTEM flush mode
class TestSystemPerSystem extends System:
	var entities_to_remove: Array[Entity] = []

	func query():
		return q.with_all([C_TestB])

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		# Use forward iteration and queue removals
		for entity in entities:
			if entity.has_component(C_TestB):
				entities_to_remove.append(entity)
				cmd.remove_entity(entity)


# Test system that uses PER_GROUP flush mode
class TestSystemPerGroup extends System:
	var spawned_count: int = 0

	func _init():
		command_buffer_flush_mode = "PER_GROUP"

	func query():
		return q.with_all([C_TestC])

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		# Spawn new entities during iteration
		for entity in entities:
			var new_entity = TestA.new()
			new_entity.add_component(C_TestD.new())
			cmd.add_entity(new_entity)
			spawned_count += 1


# Test system that uses MANUAL flush mode
class TestSystemManual extends System:
	var spawned_count: int = 0

	func _init():
		command_buffer_flush_mode = "MANUAL"

	func query():
		return q.with_all([C_TestC])

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		# Spawn new entities during iteration
		for entity in entities:
			var new_entity = TestA.new()
			new_entity.add_component(C_TestD.new())
			cmd.add_entity(new_entity)
			spawned_count += 1


# Test system that depends on command buffer results
class TestSystemDependent extends System:
	var processed_count: int = 0

	func query():
		return q.with_all([C_TestD])

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		processed_count = entities.size()


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		# Clear systems
		for group in world.systems_by_group.keys():
			world.systems_by_group[group].clear()
		# Clear entities array (entities are auto_free'd by gdUnit)
		world.entities.clear()
		# Clear relationship indexes
		world.relationship_entity_index.clear()
		world.reverse_relationship_index.clear()
		# Clear archetype system to prevent stale entity references across tests
		for archetype in world.archetypes.values():
			archetype.add_edges.clear()
			archetype.remove_edges.clear()
		world.archetypes.clear()
		world.entity_to_archetype.clear()
		# Clear query cache and entity ID registry
		world._query_archetype_cache.clear()
		world.entity_id_registry.clear()


func test_per_system_flush_mode():
	# Create test system with PER_SYSTEM mode
	var test_system = TestSystemPerSystem.new()
	world.add_system(test_system)

	# Create test entities
	var entity1 = auto_free(TestA.new())
	var entity2 = auto_free(TestA.new())
	entity1.add_component(C_TestB.new())
	entity2.add_component(C_TestB.new())

	world.add_entity(entity1)
	world.add_entity(entity2)

	# Verify entities are in world
	assert_int(world.entities.size()).is_equal(2)

	# Process the system
	world.process(0.016, "")

	# With PER_SYSTEM mode, entities should be removed immediately after system
	assert_int(world.entities.size()).is_equal(0)
	assert_int(test_system.entities_to_remove.size()).is_equal(2)


func test_per_group_flush_mode():
	# Create spawner system with PER_GROUP mode
	var spawner_system = TestSystemPerGroup.new()
	world.add_system(spawner_system)

	# Create dependent system
	var dependent_system = TestSystemDependent.new()
	world.add_system(dependent_system)

	# Create initial entity
	var entity = auto_free(TestC.new())
	entity.add_component(C_TestC.new())
	world.add_entity(entity)

	# Process all systems
	world.process(0.016, "")

	# With PER_GROUP mode, new entities are added after all systems in group complete
	# So dependent_system should NOT see the new entities in this frame
	assert_int(spawner_system.spawned_count).is_equal(1)
	assert_int(dependent_system.processed_count).is_equal(0)

	# Process again - now dependent system should see the spawned entity
	world.process(0.016, "")
	assert_int(dependent_system.processed_count).is_equal(1)


func test_manual_flush_mode():
	# Create spawner system with MANUAL mode
	var spawner_system = TestSystemManual.new()
	world.add_system(spawner_system)

	# Create dependent system
	var dependent_system = TestSystemDependent.new()
	world.add_system(dependent_system)

	# Create initial entity
	var entity = auto_free(TestC.new())
	entity.add_component(C_TestC.new())
	world.add_entity(entity)

	# Process all systems
	world.process(0.016, "")

	# With MANUAL mode, new entities are NOT added automatically
	# They require manual flush_command_buffers() call
	assert_int(spawner_system.spawned_count).is_equal(1)
	assert_int(dependent_system.processed_count).is_equal(0)

	# Process again - dependent system STILL should not see the entity (no manual flush yet)
	world.process(0.016, "")
	assert_int(dependent_system.processed_count).is_equal(0)

	# Manually flush command buffers
	world.flush_command_buffers()

	# NOW process - dependent system should see the spawned entities
	# (spawner ran twice before flush, so 2 entities with C_TestD were queued)
	world.process(0.016, "")
	assert_int(dependent_system.processed_count).is_equal(2)


func test_multiple_systems_per_system_mode():
	# Create two systems with PER_SYSTEM mode
	var system1 = TestSystemPerSystem.new()
	var system2 = TestSystemPerSystem.new()

	world.add_system(system1)
	world.add_system(system2)

	# Create entities
	var entity1 = auto_free(TestA.new())
	var entity2 = auto_free(TestA.new())
	entity1.add_component(C_TestB.new())
	entity2.add_component(C_TestB.new())

	world.add_entity(entity1)
	world.add_entity(entity2)

	# Process
	world.process(0.016, "")

	# Both systems should have processed and flushed
	# system1 removes entities, so system2 won't see them
	assert_int(system1.entities_to_remove.size()).is_equal(2)
	assert_int(system2.entities_to_remove.size()).is_equal(0)  # No entities left to process


func test_mixed_flush_modes():
	# Create system with PER_SYSTEM mode (processes first)
	var per_system = TestSystemPerSystem.new()
	world.add_system(per_system)

	# Create system with PER_GROUP mode (processes second)
	var per_group = TestSystemPerGroup.new()
	world.add_system(per_group)

	# Create entities
	var entity1 = auto_free(TestA.new())
	entity1.add_component(C_TestB.new())
	entity1.add_component(C_TestC.new())

	var entity2 = auto_free(TestC.new())
	entity2.add_component(C_TestC.new())

	world.add_entity(entity1)
	world.add_entity(entity2)

	# Process
	world.process(0.016, "")

	# per_system should have removed entity1 immediately
	# per_group should have seen entity2 and queued a spawn (flushed at end of group)
	assert_int(per_system.entities_to_remove.size()).is_equal(1)
	assert_int(per_group.spawned_count).is_equal(1)

	# New entity should exist after group flush
	assert_int(world.entities.size()).is_equal(2)  # entity2 + newly spawned


func test_command_buffer_with_no_commands():
	# Create system that doesn't queue any commands
	var test_system = TestSystemPerSystem.new()
	world.add_system(test_system)

	# Create entity without C_TestB (won't be removed)
	var entity = auto_free(TestA.new())
	world.add_entity(entity)

	# Process
	world.process(0.016, "")

	# Entity should still exist
	assert_int(world.entities.size()).is_equal(1)
	assert_int(test_system.entities_to_remove.size()).is_equal(0)


func test_command_buffer_lazy_initialization():
	# Create a simple system
	var test_system = System.new()
	world.add_system(test_system)

	# cmd should not be initialized yet
	assert_bool(test_system.has_pending_commands()).is_false()

	# Accessing cmd should initialize it
	var cmd_ref = test_system.cmd
	assert_object(cmd_ref).is_not_null()
	assert_object(test_system.cmd).is_not_null()

	# Second access should return same instance
	assert_object(test_system.cmd).is_same(cmd_ref)
