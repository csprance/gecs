## Performance tests for Component operations in GECS
class_name PerformanceTestComponents
extends PerformanceTestBase

var test_world: World
var test_entities: Array[Entity] = []


func before_test():
	super.before_test()
	test_world = create_test_world()
	test_entities.clear()


func after_test():
	# Clean up test entities
	for entity in test_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	test_entities.clear()

	if test_world:
		test_world.purge()
		test_world = null


## Test component addition performance
func test_component_addition_small_scale():
	# Pre-create entities
	for i in SMALL_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var add_components = func():
		for entity in test_entities:
			entity.add_component(C_TestA.new())

	benchmark("Component_Addition_Small_Scale", add_components)
	print_performance_results()

	# Assert reasonable performance (should add components to 100 entities in under 10ms)
	assert_performance_threshold(
		"Component_Addition_Small_Scale", 10.0, "Component addition too slow"
	)


func test_component_addition_medium_scale():
	# Pre-create entities
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var add_components = func():
		for entity in test_entities:
			entity.add_component(C_TestA.new())

	benchmark("Component_Addition_Medium_Scale", add_components)
	print_performance_results()

	# Assert reasonable performance (should add components to 1000 entities in under 75ms)
	assert_performance_threshold(
		"Component_Addition_Medium_Scale", 75.0, "Component addition too slow at medium scale"
	)


## Test multiple component additions per entity
func test_multiple_component_addition():
	# Pre-create entities
	for i in SMALL_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var add_multiple_components = func():
		for entity in test_entities:
			entity.add_component(C_TestA.new())
			entity.add_component(C_TestB.new())
			entity.add_component(C_TestC.new())

	benchmark("Multiple_Component_Addition", add_multiple_components)
	print_performance_results()

	# Assert reasonable performance (should add 3 components to 100 entities in under 20ms)
	assert_performance_threshold(
		"Multiple_Component_Addition", 20.0, "Multiple component addition too slow"
	)


## Test component removal performance
func test_component_removal_small_scale():
	# Pre-create entities with components
	for i in SMALL_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var remove_components = func():
		for entity in test_entities:
			var component = entity.get_component(C_TestA)
			if component:
				entity.remove_component(component)

	benchmark("Component_Removal_Small_Scale", remove_components)
	print_performance_results()

	# Assert reasonable performance (should remove components from 100 entities in under 10ms)
	assert_performance_threshold(
		"Component_Removal_Small_Scale", 10.0, "Component removal too slow"
	)


## Test component lookup performance
func test_component_lookup_performance():
	# Pre-create entities with components
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())
		if i % 2 == 0:
			entity.add_component(C_TestC.new())
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var lookup_components = func():
		var found_count = 0
		for entity in test_entities:
			if entity.get_component(C_TestA):
				found_count += 1
			if entity.get_component(C_TestB):
				found_count += 1
			if entity.get_component(C_TestC):
				found_count += 1
		# Should find components
		assert_that(found_count).is_greater(0)

	benchmark("Component_Lookup_Performance", lookup_components)
	print_performance_results()

	# Assert reasonable performance (should lookup components in 1000 entities in under 30ms)
	assert_performance_threshold("Component_Lookup_Performance", 30.0, "Component lookup too slow")


## Test component has_component performance
func test_component_has_check_performance():
	# Pre-create entities with components
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var check_components = func():
		var has_count = 0
		for entity in test_entities:
			if entity.has_component(C_TestA):
				has_count += 1
			if entity.has_component(C_TestB):
				has_count += 1
		# Should find components
		assert_that(has_count).is_greater(0)

	benchmark("Component_Has_Check_Performance", check_components)
	print_performance_results()

	# Assert reasonable performance (should check components in 1000 entities in under 25ms)
	assert_performance_threshold(
		"Component_Has_Check_Performance", 25.0, "Component has_component check too slow"
	)


## Test component indexing performance (world-level)
func test_component_indexing_performance():
	var entities_to_add: Array[Entity] = []

	# Pre-create entities with components
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		entity.add_component(C_TestA.new())
		if i % 2 == 0:
			entity.add_component(C_TestB.new())
		entities_to_add.append(entity)

	# Test adding entities (which triggers indexing)
	var index_entities = func():
		for entity in entities_to_add:
			test_world.add_entity(entity, null, false)

	benchmark("Component_Indexing_Performance", index_entities)
	print_performance_results()

	# Verify indexing worked
	assert_that(test_world.component_entity_index.size()).is_greater(0)

	# Assert reasonable performance (should index 1000 entities in under 100ms)
	assert_performance_threshold(
		"Component_Indexing_Performance", 100.0, "Component indexing too slow"
	)


## Test bulk component operations
func test_bulk_component_operations():
	# Pre-create entities
	for i in SMALL_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var components_a: Array[Component] = []
	var components_b: Array[Component] = []

	# Create components in bulk
	for i in SMALL_SCALE:
		components_a.append(C_TestA.new())
		components_b.append(C_TestB.new())

	var bulk_add_components = func():
		for i in SMALL_SCALE:
			test_entities[i].add_components([components_a[i], components_b[i]])

	benchmark("Bulk_Component_Addition", bulk_add_components)
	print_performance_results()

	# Assert reasonable performance (should bulk add components to 100 entities in under 15ms)
	assert_performance_threshold(
		"Bulk_Component_Addition", 15.0, "Bulk component addition too slow"
	)


## Test component property access performance
func test_component_property_access():
	# Pre-create entities with components that have properties
	for i in SMALL_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		var comp_a = C_TestA.new()
		entity.add_component(comp_a)
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	var access_properties = func():
		for entity in test_entities:
			var comp = entity.get_component(C_TestA)
			if comp:
				# Access component properties (assuming C_TestA has some properties)
				var _dummy = comp.serialize()  # This accesses all properties

	benchmark("Component_Property_Access", access_properties)
	print_performance_results()

	# Assert reasonable performance (should access properties in 100 entities in under 10ms)
	assert_performance_threshold(
		"Component_Property_Access", 10.0, "Component property access too slow"
	)


## Test component cache performance (path caching optimization)
func test_component_path_cache_performance():
	# Pre-create entities
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	# Test repeated component additions/removals (should benefit from path caching)
	var cache_test = func():
		for entity in test_entities:
			var comp = C_TestA.new()
			entity.add_component(comp)
			entity.remove_component(comp)

	benchmark("Component_Path_Cache_Performance", cache_test)
	print_performance_results()

	# Assert reasonable performance (should handle 1000 add/remove cycles in under 100ms)
	assert_performance_threshold(
		"Component_Path_Cache_Performance", 100.0, "Component path caching not effective"
	)


## Run all component performance tests
func test_run_all_component_benchmarks():
	test_component_addition_small_scale()
	after_test()
	before_test()

	test_component_addition_medium_scale()
	after_test()
	before_test()

	test_multiple_component_addition()
	after_test()
	before_test()

	test_component_removal_small_scale()
	after_test()
	before_test()

	test_component_lookup_performance()
	after_test()
	before_test()

	test_component_has_check_performance()
	after_test()
	before_test()

	test_component_indexing_performance()
	after_test()
	before_test()

	test_bulk_component_operations()
	after_test()
	before_test()

	test_component_property_access()
	after_test()
	before_test()

	test_component_path_cache_performance()

	# Save results
	save_performance_results("res://reports/component_performance_results.json")
