extends GdUnitTestSuite

## Test archetype-based system execution

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


func test_archetype_system_processes_entities():
	# Create test system that uses archetype mode
	var test_system = ArchetypeTestSystem.new()
	world.add_system(test_system)

	# Create entities with components
	var entity1 = Entity.new()
	entity1.name = "Entity1"
	world.add_entity(entity1, [C_TestA.new()])

	var entity2 = Entity.new()
	entity2.name = "Entity2"
	world.add_entity(entity2, [C_TestA.new()])

	# Process the system
	world.process(0.1)

	# Verify archetype method was called
	assert_int(test_system.archetype_call_count).is_equal(1)
	assert_int(test_system.entities_processed).is_equal(2)


func test_archetype_iteration_order_matches_iterate():
	# System that checks component order
	var test_system = ArchetypeOrderTestSystem.new()
	world.add_system(test_system)

	# Create entity with multiple components
	var entity = Entity.new()
	entity.name = "TestEntity"
	world.add_entity(entity, [C_TestB.new(), C_TestA.new()])

	# Process
	world.process(0.1)

	# Verify components were in correct order (as specified in iterate())
	assert_bool(test_system.order_correct).is_true()


func test_archetype_processes_entities_with_extra_components():
	# Query for A and B, but entity has A, B, and C
	var test_system = ArchetypeSubsetTestSystem.new()
	world.add_system(test_system)

	# Entity has MORE components than query asks for
	var entity = Entity.new()
	entity.name = "ExtraComponents"
	world.add_entity(entity, [C_TestA.new(), C_TestB.new(), C_TestC.new()])

	# Should still match and process
	world.process(0.1)

	assert_int(test_system.entities_processed).is_equal(1)


func test_archetype_processes_multiple_archetypes():
	# System that tracks archetype calls
	var test_system = ArchetypeMultipleArchetypesTestSystem.new()
	world.add_system(test_system)

	# Create entities with different component combinations
	# Archetype 1: [A, B]
	var entity1 = Entity.new()
	world.add_entity(entity1, [C_TestA.new(), C_TestB.new()])

	var entity2 = Entity.new()
	world.add_entity(entity2, [C_TestA.new(), C_TestB.new()])

	# Archetype 2: [A, B, C]
	var entity3 = Entity.new()
	world.add_entity(entity3, [C_TestA.new(), C_TestB.new(), C_TestC.new()])

	# Process
	world.process(0.1)

	# Should be called once per archetype
	assert_int(test_system.archetype_call_count).is_equal(2)
	assert_int(test_system.total_entities_processed).is_equal(3)


func test_archetype_column_data_is_correct():
	# System that verifies column data
	var test_system = ArchetypeColumnDataTestSystem.new()
	world.add_system(test_system)

	# Create entities with specific values
	var entity1 = Entity.new()
	var comp_a1 = C_TestA.new()
	comp_a1.value = 10
	world.add_entity(entity1, [comp_a1])

	var entity2 = Entity.new()
	var comp_a2 = C_TestA.new()
	comp_a2.value = 20
	world.add_entity(entity2, [comp_a2])

	# Process
	world.process(0.1)

	# Verify column had correct values
	assert_array(test_system.values_seen).contains_exactly([10, 20])


func test_archetype_modifies_components():
	# System that modifies component values
	var test_system = ArchetypeModifyTestSystem.new()
	world.add_system(test_system)

	var entity = Entity.new()
	var comp = C_TestA.new()
	comp.value = 5
	world.add_entity(entity, [comp])

	# Process multiple times
	world.process(0.1)
	world.process(0.1)
	world.process(0.1)

	# Value should have been incremented each time
	# Get the component from the entity (not the local reference)
	var updated_comp = entity.get_component(C_TestA)
	assert_int(updated_comp.value).is_equal(8)


func test_archetype_works_without_iterate_call():
	# System that doesn't call iterate() still works, just gets empty components array
	var test_system = ArchetypeNoIterateSystem.new()
	world.add_system(test_system)

	var entity = Entity.new()
	world.add_entity(entity, [C_TestA.new()])

	# Should work fine - system can use get_component() instead
	world.process(0.1)

	# System should have processed the entity
	assert_int(test_system.processed).is_equal(1)
