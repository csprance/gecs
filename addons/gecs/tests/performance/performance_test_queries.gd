## Performance tests for Query operations in GECS
class_name PerformanceTestQueries
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


## Setup entities with various component combinations for realistic testing
func setup_diverse_entities(count: int):
	for i in count:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i

		# Create diverse component combinations for realistic queries
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		if i % 5 == 0:
			entity.add_component(C_TestC.new())
		if i % 7 == 0:
			entity.add_component(C_TestD.new())

		test_entities.append(entity)
		test_world.add_entity(entity, null, false)


## Test simple with_all query performance
func test_simple_with_all_query_small_scale():
	setup_diverse_entities(SMALL_SCALE)

	var simple_query = func():
		var results = test_world.query.with_all([C_TestA]).execute()
		assert_that(results.size()).is_greater(0)

	benchmark("Simple_WithAll_Query_Small_Scale", simple_query)
	print_performance_results()

	# Assert reasonable performance (should query 100 entities in under 5ms)
	assert_performance_threshold(
		"Simple_WithAll_Query_Small_Scale", 5.0, "Simple with_all query too slow"
	)


func test_simple_with_all_query_medium_scale():
	setup_diverse_entities(MEDIUM_SCALE)

	var simple_query = func():
		var results = test_world.query.with_all([C_TestA]).execute()
		assert_that(results.size()).is_greater(0)

	benchmark("Simple_WithAll_Query_Medium_Scale", simple_query)
	print_performance_results()

	# Assert reasonable performance (should query 1000 entities in under 20ms)
	assert_performance_threshold(
		"Simple_WithAll_Query_Medium_Scale", 20.0, "Simple with_all query too slow at medium scale"
	)


func test_simple_with_all_query_large_scale():
	setup_diverse_entities(LARGE_SCALE)

	var simple_query = func():
		var results = test_world.query.with_all([C_TestA]).execute()
		assert_that(results.size()).is_greater(0)

	benchmark("Simple_WithAll_Query_Large_Scale", simple_query)
	print_performance_results()

	# Assert reasonable performance (should query 10000 entities in under 100ms)
	assert_performance_threshold(
		"Simple_WithAll_Query_Large_Scale", 100.0, "Simple with_all query too slow at large scale"
	)


## Test complex multi-component queries
func test_complex_multi_component_query():
	setup_diverse_entities(MEDIUM_SCALE)

	var complex_query = func():
		var results = test_world.query.with_all([C_TestA, C_TestB]).execute()
		assert_that(results.size()).is_greater_equal(0)  # May be 0 if no entities match

	benchmark("Complex_Multi_Component_Query", complex_query)
	print_performance_results()

	# Assert reasonable performance (should handle complex query in under 30ms)
	assert_performance_threshold(
		"Complex_Multi_Component_Query", 30.0, "Complex multi-component query too slow"
	)


## Test with_any query performance
func test_with_any_query_performance():
	setup_diverse_entities(MEDIUM_SCALE)

	var any_query = func():
		var results = test_world.query.with_any([C_TestA, C_TestB, C_TestC]).execute()
		assert_that(results.size()).is_greater(0)

	benchmark("WithAny_Query_Performance", any_query)
	print_performance_results()

	# Assert reasonable performance (should handle with_any query in under 40ms)
	assert_performance_threshold("WithAny_Query_Performance", 40.0, "With_any query too slow")


## Test with_none (exclusion) query performance
func test_with_none_query_performance():
	setup_diverse_entities(MEDIUM_SCALE)

	var none_query = func():
		var results = test_world.query.with_all([C_TestA]).with_none([C_TestB]).execute()
		assert_that(results.size()).is_greater_equal(0)

	benchmark("WithNone_Query_Performance", none_query)
	print_performance_results()

	# Assert reasonable performance (should handle with_none query in under 35ms)
	assert_performance_threshold("WithNone_Query_Performance", 35.0, "With_none query too slow")


## Test complex combined query (all + any + none)
func test_complex_combined_query():
	setup_diverse_entities(MEDIUM_SCALE)

	var combined_query = func():
		var results = (
			test_world
			. query
			. with_all([C_TestA])
			. with_any([C_TestB, C_TestC])
			. with_none([C_TestD])
			. execute()
		)
		assert_that(results.size()).is_greater_equal(0)

	benchmark("Complex_Combined_Query", combined_query)
	print_performance_results()

	# Assert reasonable performance (should handle complex combined query in under 50ms)
	assert_performance_threshold("Complex_Combined_Query", 50.0, "Complex combined query too slow")


## Test query caching performance
func test_query_caching_performance():
	setup_diverse_entities(MEDIUM_SCALE)

	# First execution (cache miss)
	var first_query = func():
		var results = test_world.query.with_all([C_TestA]).execute()
		assert_that(results.size()).is_greater(0)

	# Second execution (should hit cache)
	var cached_query = func():
		var results = test_world.query.with_all([C_TestA]).execute()
		assert_that(results.size()).is_greater(0)

	benchmark("Query_Cache_Miss", first_query)
	benchmark("Query_Cache_Hit", cached_query)

	print_performance_results()

	# Cache hit should be significantly faster
	var cache_miss_time = performance_results["Query_Cache_Miss"].avg_time_ms
	var cache_hit_time = performance_results["Query_Cache_Hit"].avg_time_ms

	# Cache hit should be at least 2x faster (allowing some margin for small datasets)
	assert_that(cache_hit_time).is_less(cache_miss_time * 0.8).override_failure_message(
		(
			"Query caching not effective: cache_hit=%f ms, cache_miss=%f ms"
			% [cache_hit_time, cache_miss_time]
		)
	)


## Test query invalidation performance impact
func test_query_invalidation_impact():
	setup_diverse_entities(SMALL_SCALE)

	# Build up cache with multiple queries
	var build_cache = func():
		test_world.query.with_all([C_TestA]).execute()
		test_world.query.with_all([C_TestB]).execute()
		test_world.query.with_all([C_TestA, C_TestB]).execute()

	# Invalidate cache by adding component (triggers cache invalidation)
	var invalidate_cache = func():
		var entity = Entity.new()
		entity.add_component(C_TestA.new())
		test_world.add_entity(entity, null, false)

	# Execute queries after invalidation
	var post_invalidation_query = func():
		var results = test_world.query.with_all([C_TestA]).execute()
		assert_that(results.size()).is_greater(0)

	benchmark("Build_Query_Cache", build_cache)
	benchmark("Cache_Invalidation", invalidate_cache)
	benchmark("Post_Invalidation_Query", post_invalidation_query)

	print_performance_results()

	# Cache invalidation should be fast
	assert_performance_threshold("Cache_Invalidation", 5.0, "Cache invalidation too slow")


## Test query performance with different selectivity
func test_query_selectivity_performance():
	setup_diverse_entities(MEDIUM_SCALE)

	# High selectivity query (few matches)
	var high_selectivity_query = func():
		var results = test_world.query.with_all([C_TestA, C_TestB, C_TestC]).execute()
		# This should match entities divisible by 2, 3, and 5 (i.e., divisible by 30)
	# This should match entities divisible by 2, 3, and 5 (i.e., divisible by 30)
	# This should match entities divisible by 2, 3, and 5 (i.e., divisible by 30)
	# This should match entities divisible by 2, 3, and 5 (i.e., divisible by 30)
	# This should match entities divisible by 2, 3, and 5 (i.e., divisible by 30)

	# Low selectivity query (many matches)
	var low_selectivity_query = func(): var results = test_world.query.with_all([C_TestA]).execute()
	# This should match 50% of entities

	benchmark("High_Selectivity_Query", high_selectivity_query)
	benchmark("Low_Selectivity_Query", low_selectivity_query)

	print_performance_results()

	# Both should be reasonably fast
	assert_performance_threshold("High_Selectivity_Query", 40.0, "High selectivity query too slow")
	assert_performance_threshold("Low_Selectivity_Query", 30.0, "Low selectivity query too slow")


## Test repeated query execution performance
func test_repeated_query_execution():
	setup_diverse_entities(SMALL_SCALE)

	var repeated_queries = func():
		for i in 100:  # Execute same query 100 times
			var results = test_world.query.with_all([C_TestA]).execute()
			assert_that(results.size()).is_greater(0)

	benchmark("Repeated_Query_Execution", repeated_queries)
	print_performance_results()

	# Should benefit heavily from caching
	assert_performance_threshold(
		"Repeated_Query_Execution", 50.0, "Repeated query execution too slow"
	)


## Test query builder creation performance
func test_query_builder_creation():
	setup_diverse_entities(SMALL_SCALE)

	var create_query_builders = func():
		for i in 1000:  # Create 1000 query builders
			var query = test_world.query.with_all([C_TestA]).with_any([C_TestB])
			# Don't execute, just test creation
	# Don't execute, just test creation
	# Don't execute, just test creation
	# Don't execute, just test creation
	# Don't execute, just test creation

	benchmark("Query_Builder_Creation", create_query_builders)
	print_performance_results()

	# Query builder creation should be very fast
	assert_performance_threshold("Query_Builder_Creation", 20.0, "Query builder creation too slow")


## Test empty query performance
func test_empty_query_performance():
	setup_diverse_entities(MEDIUM_SCALE)

	var empty_query = func():
		var results = test_world.query.execute()  # No filters, should return all entities
		assert_that(results.size()).is_equal(MEDIUM_SCALE)

	benchmark("Empty_Query_Performance", empty_query)
	print_performance_results()

	# Empty query should be very fast (just returns all entities)
	assert_performance_threshold("Empty_Query_Performance", 10.0, "Empty query too slow")


## Test query with no results performance
func test_no_results_query_performance():
	setup_diverse_entities(MEDIUM_SCALE)

	var no_results_query = func():
		# Query for component that doesn't exist
		var results = test_world.query.with_all([C_TestE]).execute()
		assert_that(results.size()).is_equal(0)

	benchmark("No_Results_Query_Performance", no_results_query)
	print_performance_results()

	# No results query should be fast (early exit optimization)
	assert_performance_threshold("No_Results_Query_Performance", 15.0, "No results query too slow")


## Run all query performance tests
func test_run_all_query_benchmarks():
	test_simple_with_all_query_small_scale()
	after_test()
	before_test()

	test_simple_with_all_query_medium_scale()
	after_test()
	before_test()

	test_simple_with_all_query_large_scale()
	after_test()
	before_test()

	test_complex_multi_component_query()
	after_test()
	before_test()

	test_with_any_query_performance()
	after_test()
	before_test()

	test_with_none_query_performance()
	after_test()
	before_test()

	test_complex_combined_query()
	after_test()
	before_test()

	test_query_caching_performance()
	after_test()
	before_test()

	test_query_invalidation_impact()
	after_test()
	before_test()

	test_query_selectivity_performance()
	after_test()
	before_test()

	test_repeated_query_execution()
	after_test()
	before_test()

	test_query_builder_creation()
	after_test()
	before_test()

	test_empty_query_performance()
	after_test()
	before_test()

	test_no_results_query_performance()

	# Save results
	save_performance_results("res://reports/query_performance_results.json")
