## Performance tests for System processing in GECS
class_name PerformanceTestSystemProcess
extends PerformanceTestBase

var test_world: World
var test_entities: Array[Entity] = []
var test_systems: Array[System] = []


func before_test():
	super.before_test()
	test_world = create_test_world()
	test_entities.clear()
	test_systems.clear()


func after_test():
	# Free all entities properly first
	for entity in test_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	test_entities.clear()
	
	# Clean up systems first
	for system in test_systems:
		if system and is_instance_valid(system):
			system.queue_free()
	test_systems.clear()
	
	# Clean up the world thoroughly
	if test_world and is_instance_valid(test_world):
		# Free all children entities
		for child in test_world.get_children():
			if is_instance_valid(child):
				child.queue_free()
		
		# Clear world data structures
		test_world.entities.clear()
		test_world.systems.clear()
		test_world.component_entity_index.clear()
		test_world.relationship_entity_index.clear()
		test_world.reverse_relationship_index.clear()
		test_world._query_result_cache.clear()
		
		# Remove and free the world
		remove_child(test_world)
		test_world.queue_free()
		test_world = null
	
	# Call parent cleanup
	super.after_test()


## Setup entities for system processing tests
func setup_entities_for_systems(count: int):
	for i in count:
		var entity = Entity.new()
		entity.name = "SystemTestEntity_%d" % i

		# Create entities that match different system queries
		entity.add_component(C_TestA.new())
		if i % 2 == 0:
			entity.add_component(C_TestB.new())
		if i % 4 == 0:
			entity.add_component(C_TestC.new())

		test_entities.append(entity)
		test_world.add_entity(entity, null, true)


## Setup systems
func setup_systems(a_count: int, b_count: int, process_empty: bool):
	# Simulates a game with multiple systems
	for i in range(a_count):
		var system = ProcessTestSystem_A.new(process_empty)
		system.name = "System_%d" % i
		test_systems.append(system)
		test_world.add_system(system)
		system.reset_count()
		
	for i in range(b_count):
		var system = ProcessTestSystem_B.new(process_empty)
		system.name = "System_%d" % i
		test_systems.append(system)
		test_world.add_system(system)
		system.reset_count()


## Test simple system processing performance
func system_processing_large_scale(process_empty: bool):
	setup_entities_for_systems(LARGE_SCALE)
	setup_systems(50, 50, process_empty)

	var process_systems = func():
		for i in range(60):
			test_world.process(0.016) # Simulate 60 FPS delta

	benchmark("Simple_System_Processing_Large_Scale", process_systems)
	print_performance_results()

	var total: int = 0
	for system in test_systems:
		total += system.process_count
	# Verify system actually processed entities
	assert_that(total).is_greater(0)
	print("Total process calls: %d" % total)

	# Assert reasonable performance (should process 10000 entities in under 150ms)
	assert_performance_threshold(
		"Simple_System_Processing_Large_Scale",
		150.0,
		"Simple system processing too slow at large scale"
	)