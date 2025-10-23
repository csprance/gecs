## Cache Key Generation Performance Tests
## Tests the performance of cache key generation with different query complexities
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Test cache key generation with varying numbers of components
## This tests the raw cache key generation performance
func test_cache_key_generation(num_components: int, test_parameters := [[1], [5], [10], [20]]):
	# Build arrays of component types for the test
	var all_components = []
	var any_components = []
	var exclude_components = []

	# Use available test components
	var available_components = [C_TestA, C_TestB, C_TestC, C_TestD, C_TestE, C_TestF, C_TestG, C_TestH]

	# Distribute components across all/any/exclude
	for i in num_components:
		var comp = available_components[i % available_components.size()]
		if i % 3 == 0:
			all_components.append(comp)
		elif i % 3 == 1:
			any_components.append(comp)
		else:
			exclude_components.append(comp)

	# Time generating cache keys 10000 times
	var time_ms = PerfHelpers.time_it(func():
		for i in 10000:
			var key = QueryCacheKey.build(all_components, any_components, exclude_components)
	)

	PerfHelpers.record_result("cache_key_generation", num_components, time_ms)


## Test cache hit performance with varying world sizes
## This measures the complete cached query execution time
func test_cache_hit_performance(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Setup entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		world.add_entity(entity, null, false)

	# Execute query once to populate cache
	var __ = world.query.with_all([C_TestA, C_TestB]).execute()

	# Time 1000 cache hit queries
	var time_ms = PerfHelpers.time_it(func():
		for i in 1000:
			var entities = world.query.with_all([C_TestA, C_TestB]).execute()
	)

	PerfHelpers.record_result("cache_hit_performance", scale, time_ms)


## Test cache miss vs cache hit comparison
## This shows the performance difference between cache miss and hit
func test_cache_miss_vs_hit(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Setup entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		world.add_entity(entity, null, false)

	# Measure cache miss (first query)
	var miss_time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_all([C_TestA, C_TestB]).execute()
	)

	# Measure cache hit (subsequent query)
	var hit_time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_all([C_TestA, C_TestB]).execute()
	)

	PerfHelpers.record_result("cache_miss", scale, miss_time_ms)
	PerfHelpers.record_result("cache_hit", scale, hit_time_ms)

	# Print comparison
	var speedup = miss_time_ms / hit_time_ms if hit_time_ms > 0 else 0
	print("  Cache speedup at scale %d: %.1fx (miss=%.3fms, hit=%.3fms)" % [
		scale, speedup, miss_time_ms, hit_time_ms
	])


## Test cache key stability across query builder instances
## Ensures the same query produces the same cache key
func test_cache_key_stability():
	# Setup some entities
	for i in 100:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		world.add_entity(entity, null, false)

	# Execute same query 100 times and collect cache stats
	var initial_stats = world.get_cache_stats()

	for i in 100:
		var entities = world.query.with_all([C_TestA, C_TestB]).execute()

	var final_stats = world.get_cache_stats()
	var hits = final_stats.cache_hits - initial_stats.cache_hits
	var misses = final_stats.cache_misses - initial_stats.cache_misses

	print("  Cache key stability: %d hits, %d misses (%.1f%% hit rate)" % [
		hits, misses, (hits * 100.0 / (hits + misses)) if (hits + misses) > 0 else 0
	])

	# We expect 1 miss (first query) and 99 hits (all subsequent queries)
	assert_int(misses).is_equal(1)
	assert_int(hits).is_equal(99)


## Test cache invalidation frequency impact
## Measures performance when cache is frequently invalidated
func test_cache_invalidation_impact(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Setup entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		world.add_entity(entity, null, false)

	# Time queries with cache invalidation after each query
	var with_invalidation_ms = PerfHelpers.time_it(func():
		for i in 100:
			var entities = world.query.with_all([C_TestA, C_TestB]).execute()
			world._query_archetype_cache.clear() # Force cache miss on next query
	)

	# Time queries without invalidation (all cache hits after first)
	var without_invalidation_ms = PerfHelpers.time_it(func():
		for i in 100:
			var entities = world.query.with_all([C_TestA, C_TestB]).execute()
	)

	PerfHelpers.record_result("cache_invalidation_impact_with", scale, with_invalidation_ms)
	PerfHelpers.record_result("cache_invalidation_impact_without", scale, without_invalidation_ms)

	var overhead = (with_invalidation_ms - without_invalidation_ms) / without_invalidation_ms * 100
	print("  Cache invalidation overhead at scale %d: %.1f%% (with=%.2fms, without=%.2fms)" % [
		scale, overhead, with_invalidation_ms, without_invalidation_ms
	])
