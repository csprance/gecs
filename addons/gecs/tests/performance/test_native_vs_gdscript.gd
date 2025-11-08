## Native vs GDScript Performance Comparison
## Tests the speedup from using C++ GDExtension for hot paths
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


## Test query cache key generation performance
## This is the first optimization - pure logic, no Godot API complexity
func test_query_cache_key_performance(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Setup component arrays (realistic query)
	var all_comps = [C_TestA, C_TestB, C_TestC]
	var any_comps = [C_TestD, C_TestE]
	var none_comps = [C_TestF]

	var has_native = ClassDB.class_exists("NativeQueryCacheKey")

	# Benchmark GDScript implementation
	var gdscript_time = PerfHelpers.time_it(func():
		for i in scale:
			var _key = QueryCacheKey._build_gdscript(all_comps, any_comps, none_comps)
	)

	# Benchmark Native implementation (if available)
	var native_time = 0.0
	if has_native:
		native_time = PerfHelpers.time_it(func():
			for i in scale:
				var _key = NativeQueryCacheKey.build(all_comps, any_comps, none_comps)
		)

	# Verify correctness - keys must match!
	if has_native:
		var gdscript_key = QueryCacheKey._build_gdscript(all_comps, any_comps, none_comps)
		var native_key = NativeQueryCacheKey.build(all_comps, any_comps, none_comps)
		assert_that(native_key).is_equal(gdscript_key)

	# Calculate speedup
	var speedup = gdscript_time / native_time if native_time > 0 else 0

	print("\n=== Query Cache Key Performance (scale=%d) ===" % scale)
	print("  GDScript: %.3f ms" % gdscript_time)
	if has_native:
		print("  Native:   %.3f ms" % native_time)
		print("  Speedup:  %.1fx ⚡" % speedup)
		print("  Expected: 10-20x")
	else:
		print("  Native:   NOT AVAILABLE (build GDExtension to enable)")

	# Record results
	PerfHelpers.record_result("query_cache_key_gdscript", scale, gdscript_time)
	if has_native:
		PerfHelpers.record_result("query_cache_key_native", scale, native_time)
		PerfHelpers.record_result("query_cache_key_speedup", scale, speedup)


## Test end-to-end query performance with native cache keys
## This shows real-world impact on query execution
func test_query_execution_with_native_cache(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Setup diverse entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		if i % 2 == 0: entity.add_component(C_TestA.new())
		if i % 3 == 0: entity.add_component(C_TestB.new())
		if i % 5 == 0: entity.add_component(C_TestC.new())
		world.add_entity(entity, null, false)

	var has_native = ClassDB.class_exists("NativeQueryCacheKey")

	# Run many queries to stress test cache key generation
	var time_ms = PerfHelpers.time_it(func():
		for i in 100:  # 100 different queries
			var query_variant = i % 8
			var q = world.query

			match query_variant:
				0: q.with_all([C_TestA])
				1: q.with_all([C_TestB])
				2: q.with_all([C_TestA, C_TestB])
				3: q.with_any([C_TestA, C_TestC])
				4: q.with_none([C_TestB])
				5: q.with_all([C_TestA]).with_none([C_TestC])
				6: q.with_any([C_TestB, C_TestC])
				7: q.with_all([C_TestA, C_TestB, C_TestC])

			var _entities = q.execute()
	)

	print("\n=== Query Execution (scale=%d, 100 queries) ===" % scale)
	print("  Time: %.3f ms" % time_ms)
	if has_native:
		print("  Using: Native cache keys ⚡")
		print("  Expected improvement: 15-30%% faster than pure GDScript")
	else:
		print("  Using: GDScript cache keys")
		print("  Tip: Build GDExtension for 15-30%% speedup")

	PerfHelpers.record_result("query_execution_mixed", scale, time_ms)
	world.purge(false)


## Test cache key correctness - native and GDScript must produce identical keys
func test_cache_key_correctness():
	if not ClassDB.class_exists("NativeQueryCacheKey"):
		print("⚠️  Skipping correctness test - NativeQueryCacheKey not available")
		return

	print("\n=== Cache Key Correctness Test ===")

	# Test various component combinations
	var test_cases = [
		# [all, any, none]
		[[C_TestA], [], []],
		[[C_TestA, C_TestB], [], []],
		[[C_TestA], [C_TestB], []],
		[[C_TestA], [], [C_TestB]],
		[[C_TestA, C_TestB], [C_TestC], [C_TestD]],
		[[], [C_TestA], []],
		[[], [], [C_TestA]],
		[[], [C_TestA, C_TestB, C_TestC], []],
	]

	var passed = 0
	var failed = 0

	for test_case in test_cases:
		var all_comps = test_case[0]
		var any_comps = test_case[1]
		var none_comps = test_case[2]

		var gdscript_key = QueryCacheKey._build_gdscript(all_comps, any_comps, none_comps)
		var native_key = NativeQueryCacheKey.build(all_comps, any_comps, none_comps)

		if gdscript_key == native_key:
			passed += 1
			print("  ✅ all=%s any=%s none=%s" % [all_comps, any_comps, none_comps])
		else:
			failed += 1
			print("  ❌ all=%s any=%s none=%s" % [all_comps, any_comps, none_comps])
			print("     GDScript: %d" % gdscript_key)
			print("     Native:   %d" % native_key)

	print("\nResults: %d passed, %d failed" % [passed, failed])
	assert_that(failed).is_equal(0)


## Test order insensitivity - [A,B,C] should produce same key as [C,A,B]
func test_cache_key_order_insensitivity():
	if not ClassDB.class_exists("NativeQueryCacheKey"):
		print("⚠️  Skipping order insensitivity test - NativeQueryCacheKey not available")
		return

	print("\n=== Cache Key Order Insensitivity Test ===")

	# Test that component order doesn't matter within each domain
	var key1 = NativeQueryCacheKey.build([C_TestA, C_TestB, C_TestC], [], [])
	var key2 = NativeQueryCacheKey.build([C_TestC, C_TestA, C_TestB], [], [])
	var key3 = NativeQueryCacheKey.build([C_TestB, C_TestC, C_TestA], [], [])

	print("  [A,B,C]: %d" % key1)
	print("  [C,A,B]: %d" % key2)
	print("  [B,C,A]: %d" % key3)

	assert_that(key1).is_equal(key2)
	assert_that(key2).is_equal(key3)
	print("  ✅ Order insensitive within domain")

	# But order across domains DOES matter
	var key_all_ab = NativeQueryCacheKey.build([C_TestA, C_TestB], [], [])
	var key_any_ab = NativeQueryCacheKey.build([], [C_TestA, C_TestB], [])

	print("\n  with_all([A,B]): %d" % key_all_ab)
	print("  with_any([A,B]): %d" % key_any_ab)

	assert_that(key_all_ab).is_not_equal(key_any_ab)
	print("  ✅ Different domains produce different keys")
