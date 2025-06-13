## Base class for GECS performance tests
## Provides timing utilities and standardized benchmarking methods
class_name PerformanceTestBase
extends GdUnitTestSuite

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const C_TestD = preload("res://addons/gecs/tests/components/c_test_d.gd")
const C_TestE = preload("res://addons/gecs/tests/components/c_test_e.gd")

## Performance test configuration
const WARMUP_ITERATIONS = 5
const MEASUREMENT_ITERATIONS = 10
const SMALL_SCALE = 100
const MEDIUM_SCALE = 1000
const LARGE_SCALE = 10000

## Performance results storage
var performance_results: Dictionary = {}


## Setup performance testing environment
func before_test():
	performance_results.clear()
	# Ensure consistent starting state
	if ECS.world:
		ECS.world.purge(false)


## Utility to measure execution time of a callable
func measure_time(callable: Callable, iterations: int = 1) -> float:
	# Clean up before measurement
	var start_time = Time.get_ticks_usec()

	for i in iterations:
		callable.call()

	var end_time = Time.get_ticks_usec()
	return (end_time - start_time) / 1000.0  # Return milliseconds


## Run a performance benchmark with warmup and multiple measurements
func benchmark(test_name: String, callable: Callable, iterations: int = 1) -> Dictionary:
	# Warmup
	for i in WARMUP_ITERATIONS:
		callable.call()

	# Actual measurements
	var times: Array[float] = []
	for i in MEASUREMENT_ITERATIONS:
		var time = measure_time(callable, iterations)
		times.append(time)

	# Calculate statistics
	var total_time = times.reduce(func(sum, time): return sum + time, 0.0)
	var avg_time = total_time / MEASUREMENT_ITERATIONS
	var min_time = times.min()
	var max_time = times.max()

	# Calculate standard deviation
	var variance = 0.0
	for time in times:
		variance += (time - avg_time) * (time - avg_time)
	variance /= MEASUREMENT_ITERATIONS
	var std_dev = sqrt(variance)

	var result = {
		"test_name": test_name,
		"iterations": iterations,
		"measurements": MEASUREMENT_ITERATIONS,
		"avg_time_ms": avg_time,
		"min_time_ms": min_time,
		"max_time_ms": max_time,
		"std_dev_ms": std_dev,
		"total_time_ms": total_time,
		"ops_per_sec": (iterations * 1000.0) / avg_time if avg_time > 0 else 0,
		"time_per_op_us": (avg_time * 1000.0) / iterations if iterations > 0 else 0
	}

	performance_results[test_name] = result
	return result


## Print performance results in a readable format
func print_performance_results():
	print("\n=== GECS Performance Test Results ===")
	for test_name in performance_results:
		var result = performance_results[test_name]
		print("\n%s:" % test_name)
		print("  Iterations: %d" % result.iterations)
		print("  Avg Time: %.3f ms (%.3f ms)" % [result.avg_time_ms, result.std_dev_ms])
		print("  Min/Max: %.3f ms / %.3f ms" % [result.min_time_ms, result.max_time_ms])
		print("  Ops/sec: %.0f" % result.ops_per_sec)
		print("  Time/op: %.2f s" % result.time_per_op_us)


## Create a basic world for testing
func create_test_world() -> World:
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	return world


## Create entities with random components for testing
func create_test_entities(count: int, world: World) -> Array[Entity]:
	var entities: Array[Entity] = []

	for i in count:
		var entity = Entity.new()
		entity.name = "TestEntity_%d" % i
		entities.append(entity)
		world.add_entity(entity)

		# Add random components to make realistic scenarios
		if i % 3 == 0:
			entity.add_component(C_TestA.new())
		if i % 5 == 0:
			entity.add_component(C_TestB.new())
		if i % 7 == 0:
			entity.add_component(C_TestC.new())

	return entities


## Assert performance thresholds (fail if performance degrades significantly)
func assert_performance_threshold(test_name: String, max_time_ms: float, message: String = ""):
	assert_that(performance_results.has(test_name)).is_true()
	var result = performance_results[test_name]
	var actual_time = result.avg_time_ms
	var threshold_message = "%s - Expected <%f ms, got %f ms" % [message, max_time_ms, actual_time]
	assert_that(actual_time).is_less(max_time_ms).override_failure_message(threshold_message)


## Compare performance between two test results (for regression testing)
func assert_performance_regression(
	baseline_test: String, current_test: String, max_regression_percent: float = 20.0
):
	assert_that(performance_results.has(baseline_test)).is_true()
	assert_that(performance_results.has(current_test)).is_true()

	var baseline_time = performance_results[baseline_test].avg_time_ms
	var current_time = performance_results[current_test].avg_time_ms
	var regression_percent = ((current_time - baseline_time) / baseline_time) * 100.0

	var message = (
		"Performance regression: %s vs %s - %.1f%% slower (%.3f ms vs %.3f ms)"
		% [current_test, baseline_test, regression_percent, current_time, baseline_time]
	)

	assert_that(regression_percent).is_less(max_regression_percent).override_failure_message(
		message
	)


## Save performance results to file for tracking over time
func save_performance_results(filename: String = ""):
	if filename.is_empty():
		filename = (
			"res://reports/performance_results_%s.json"
			% Time.get_datetime_string_from_system().replace(":", "-")
		)

	# Ensure reports directory exists
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists("reports"):
		dir.make_dir("reports")

	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var data = {
			"timestamp": Time.get_datetime_string_from_system(),
			"godot_version": Engine.get_version_info(),
			"results": performance_results
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Performance results saved to: %s" % filename)
	else:
		print("Failed to save performance results to: %s" % filename)
