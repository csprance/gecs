## Performance tests for Entity operations in GECS
class_name PerformanceTestEntities
extends PerformanceTestBase

var test_world: World
var test_entities: Array[Entity] = []


func before_test():
	super.before_test()
	test_world = create_test_world()
	test_entities.clear()


func after_test():
	# Remove entities from world first to avoid orphans
	if test_world and is_instance_valid(test_world):
		# Remove all test entities from world first
		for entity in test_entities:
			if is_instance_valid(entity) and entity in test_world.entities:
				test_world.remove_entity(entity)
	
	# Free all entities properly
	for entity in test_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	test_entities.clear()
	
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

## Run all entity performance tests
func after():
	# Save results using new timestamped format
	save_performance_results("entity-performance")
	
	# Optionally compare with historical data and print report
	var comparison = compare_with_historical("entity-performance")
	if not comparison.is_empty():
		print_performance_comparison(comparison)

	
## Test entity creation performance
func test_entity_creation_small_scale():
	var create_entities = func():
		for i in SMALL_SCALE:
			var entity = Entity.new()
			entity.name = "PerfTestEntity_%d" % i
			test_entities.append(entity)

	var result = benchmark("Entity_Creation_Small_Scale", create_entities)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Assert reasonable performance (should create 100 entities in under 10ms)
	assert_performance_threshold("Entity_Creation_Small_Scale", 100.0, "Entity creation too slow")


func test_entity_creation_medium_scale():
	var create_entities = func():
		for i in MEDIUM_SCALE:
			var entity = Entity.new()
			entity.name = "PerfTestEntity_%d" % i
			test_entities.append(entity)

	var result = benchmark("Entity_Creation_Medium_Scale", create_entities)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Assert reasonable performance (should create 1000 entities in under 50ms)
	assert_performance_threshold(
		"Entity_Creation_Medium_Scale", 50.0, "Entity creation too slow at medium scale"
	)


func test_entity_world_addition_small_scale():
	# Pre-create entities
	for i in SMALL_SCALE:
		var entity = Entity.new()
		entity.name = "PerfTestEntity_%d" % i
		test_entities.append(entity)

	var add_entities = func():
		for entity in test_entities:
			test_world.add_entity(entity, null, false) # Don't add to tree for perf test

	var result = benchmark("Entity_World_Addition_Small_Scale", add_entities)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Assert reasonable performance (should add 100 entities in under 15ms)
	assert_performance_threshold(
		"Entity_World_Addition_Small_Scale", 15.0, "Entity world addition too slow"
	)


func test_entity_world_addition_medium_scale():
	# Pre-create entities
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "PerfTestEntity_%d" % i
		test_entities.append(entity)

	var add_entities = func():
		for entity in test_entities:
			test_world.add_entity(entity, null, false) # Don't add to tree for perf test

	var result = benchmark("Entity_World_Addition_Medium_Scale", add_entities)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Assert reasonable performance (should add 1000 entities in under 100ms)
	assert_performance_threshold(
		"Entity_World_Addition_Medium_Scale",
		100.0,
		"Entity world addition too slow at medium scale"
	)


func test_entity_removal_small_scale():
	# Pre-create and add entities
	for i in SMALL_SCALE:
		var entity = Entity.new()
		entity.name = "PerfTestEntity_%d" % i
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var remove_entities = func():
		# Remove half the entities
		var to_remove = test_entities.slice(0, SMALL_SCALE / 2)
		for entity in to_remove:
			test_world.remove_entity(entity)

	var result = benchmark("Entity_Removal_Small_Scale", remove_entities)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Assert reasonable performance (should remove 50 entities in under 10ms)
	assert_performance_threshold("Entity_Removal_Small_Scale", 100.0, "Entity removal too slow")


func test_entity_with_components_creation():
	var create_entities_with_components = func():
		for i in SMALL_SCALE:
			var entity = Entity.new()
			entity.name = "PerfTestEntity_%d" % i

			# Add multiple components
			entity.add_component(C_TestA.new())
			entity.add_component(C_TestB.new())
			if i % 2 == 0:
				entity.add_component(C_TestC.new())

			test_entities.append(entity)

	var result = benchmark("Entity_With_Components_Creation", create_entities_with_components)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Assert reasonable performance (should create 100 entities with components in under 25ms)
	assert_performance_threshold(
		"Entity_With_Components_Creation", 25.0, "Entity creation with components too slow"
	)


func test_bulk_entity_operations():
	var entities_batch: Array[Entity] = []

	# Create entities in batch
	var create_batch = func():
		entities_batch.clear()
		for i in MEDIUM_SCALE:
			var entity = Entity.new()
			entity.name = "BatchEntity_%d" % i
			entities_batch.append(entity)

	var add_batch = func(): test_world.add_entities(entities_batch)

	benchmark("Bulk_Entity_Creation", create_batch)
	benchmark("Bulk_Entity_Addition", add_batch)

	print_performance_results()

	# Add entities to test_entities for proper cleanup in after_test()
	test_entities.append_array(entities_batch)
	cleanup_test_entities_immediate(test_entities, test_world)


## Test entity lookup performance in world
func test_entity_lookup_performance():
	# Setup: Create entities and add to world
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "LookupEntity_%d" % i
		entity.add_component(C_TestA.new())
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	# Test: Find entities by component
	var lookup_test = func():
		var found_entities = test_world.entities.filter(func(e): return e.has_component(C_TestA))
		assert_that(found_entities.size()).is_equal(MEDIUM_SCALE)

	benchmark("Entity_Lookup_By_Component", lookup_test)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Assert reasonable performance
	assert_performance_threshold("Entity_Lookup_By_Component", 50.0, "Entity lookup too slow")


## Test memory usage with large number of entities
func test_entity_memory_stress():
	var create_stress_entities = func():
		for i in LARGE_SCALE:
			var entity = Entity.new()
			entity.name = "StressEntity_%d" % i

			# Add various components to simulate real usage
			if i % 2 == 0:
				entity.add_component(C_TestA.new())
			if i % 3 == 0:
				entity.add_component(C_TestB.new())
			if i % 5 == 0:
				entity.add_component(C_TestC.new())

			test_entities.append(entity)
			test_world.add_entity(entity, null, false)

	benchmark("Entity_Memory_Stress_Test", create_stress_entities)
	print_performance_results()
	cleanup_test_entities_immediate(test_entities, test_world)

	# Verify all entities were created
	assert_that(test_world.entities.size()).is_equal(LARGE_SCALE)
