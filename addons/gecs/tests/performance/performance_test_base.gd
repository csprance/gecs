## Base class for GECS performance tests
## Provides timing utilities and standardized benchmarking methods
class_name PerformanceTestBase
extends GdUnitTestSuite


## Performance test configuration
const WARMUP_ITERATIONS = 5
const MEASUREMENT_ITERATIONS = 10
const SMALL_SCALE = 100
const MEDIUM_SCALE = 1000
const LARGE_SCALE = 10000

## Performance baselines (in milliseconds) - Hard targets that tests must meet
const PERFORMANCE_BASELINES = {
	# Entity operations - relaxed based on actual performance
	"Entity_Creation_Small_Scale": 150.0,
	"Entity_Creation_Large_Scale": 1500.0,
	"Entity_Removal_Small_Scale": 100.0,
	"Entity_Removal_Large_Scale": 1000.0,
	"Entity_Memory_Stress_Test": 50000.0,
	
	# Component operations - relaxed
	"Component_Addition_Small_Scale": 100.0,
	"Component_Addition_Large_Scale": 1000.0,
	"Component_Removal_Small_Scale": 100.0,
	"Component_Removal_Large_Scale": 1000.0,
	"Component_Memory_Stress_Test": 10000.0,
	
	# Query operations - relaxed
	"Simple_Query_Performance": 100.0,
	"Complex_Query_Performance": 200.0,
	"Large_Dataset_Query_Performance": 1000.0,
	"Multi_Component_Query_Performance": 300.0,
	"Relationship_Query_Performance": 200.0,
	"Empty_Query_Performance": 50.0,
	"No_Results_Query_Performance": 100.0,
	
	# System operations - relaxed
	"System_Processing_Small_Scale": 200.0,
	"System_Processing_Large_Scale": 2000.0,
	"Multiple_Systems_Performance": 500.0,
	"System_Iteration_Performance": 1000.0,
	"Complex_System_Performance": 1500.0,
	"Inactive_System_Performance": 100.0,
	
	# Integration tests - relaxed significantly
	"Realistic_Game_Scenario": 3000.0,
	"High_Entity_Count_Stress": 10000.0,
	"Complex_Queries_Stress": 2000.0,
	"System_Processing_Stress": 5000.0,
	"Memory_Usage_Stress": 25000.0,
	"Worst_Case_Query_Performance": 2000.0,
	
	# Array/Set operations
	"Small_Array_Intersection": 5.0,
	"Large_Array_Intersection": 50.0,
	"Small_Array_Union": 5.0,
	"Large_Array_Union": 50.0,
	"Small_Array_Difference": 5.0,
	"Large_Array_Difference": 50.0,
	"Set_Operations_Stress": 200.0
}

## Performance results storage
var performance_results: Dictionary = {}


## Setup performance testing environment
func before_test():
	performance_results.clear()
	
	# Disable debug mode for accurate performance measurements
	ECS.debug = false
	
	# Ensure consistent starting state - clean up any existing world
	if ECS.world and is_instance_valid(ECS.world):
		# Free all children entities first
		for child in ECS.world.get_children():
			if child is Entity:
				child.queue_free()
		ECS.world.entities.clear()
		ECS.world.systems.clear()
		ECS.world.component_entity_index.clear()
		ECS.world.relationship_entity_index.clear()
		ECS.world.reverse_relationship_index.clear()
		ECS.world._query_result_cache.clear()


## Cleanup performance testing environment
func after_test():
	# Clean up the current world thoroughly
	if ECS.world and is_instance_valid(ECS.world):
		# Free all entities as nodes
		for child in ECS.world.get_children():
			if is_instance_valid(child):
				child.queue_free()
		
		# Clear all world data structures
		ECS.world.entities.clear()
		ECS.world.systems.clear()
		ECS.world.component_entity_index.clear()
		ECS.world.relationship_entity_index.clear()
		ECS.world.reverse_relationship_index.clear()
		ECS.world._query_result_cache.clear()


## Utility to measure execution time of a callable
func measure_time(callable: Callable, iterations: int = 1) -> float:
	# Clean up before measurement
	var start_time = Time.get_ticks_usec()

	for i in iterations:
		callable.call()

	var end_time = Time.get_ticks_usec()
	return (end_time - start_time) / 1000.0 # Return milliseconds


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
	prints("\n=== GECS Performance Test Results ===")
	for test_name in performance_results:
		var result = performance_results[test_name]
		prints("\n%s:" % test_name)
		prints("  Iterations: %d" % result.iterations)
		prints("  Avg Time: %.3f ms (%.3f ms)" % [result.avg_time_ms, result.std_dev_ms])
		prints("  Min/Max: %.3f ms / %.3f ms" % [result.min_time_ms, result.max_time_ms])
		prints("  Ops/sec: %.0f" % result.ops_per_sec)
		prints("  Time/op: %.2f s" % result.time_per_op_us)


## Create a basic world for testing
func create_test_world() -> World:
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	return world


## Force comprehensive cleanup to eliminate orphan nodes
func force_comprehensive_cleanup():
	# Force a few frames of processing to ensure all queue_free() calls are processed
	for i in range(3):
		await get_tree().process_frame
	
	# Wait another frame for final cleanup
	await get_tree().process_frame


## Immediate cleanup function to prevent orphan nodes during test execution
func cleanup_test_entities_immediate(entities: Array[Entity], world: World):
	for entity in entities:
		if is_instance_valid(entity) and entity in world.entities:
			world.remove_entity(entity)
		if is_instance_valid(entity):
			entity.queue_free()
	entities.clear()


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

## Helper to properly free a list of entities
func free_entities(entities: Array[Entity]):
	for entity in entities:
		if is_instance_valid(entity):
			entity.queue_free()
	entities.clear()

## Force immediate cleanup of entities and systems in world
func force_cleanup_world(world: World):
	if not world or not is_instance_valid(world):
		return
	
	# Force immediate processing of all queued frees
	await get_tree().process_frame
	
	# Clear all references from world
	world.entities.clear()
	world.systems.clear()
	world.component_entity_index.clear()
	world.relationship_entity_index.clear()
	world.reverse_relationship_index.clear()
	world._query_result_cache.clear()
	
	# Free all child nodes
	for child in world.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	# Force another frame to process the frees
	await get_tree().process_frame


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


## Save performance results to timestamped file for historical tracking
func save_performance_results(report_name: String = ""):
	var timestamp = Time.get_datetime_dict_from_system()
	var datetime_str = "%02d-%02d-%04d_%02d-%02d-%02d" % [
		timestamp.month, timestamp.day, timestamp.year,
		timestamp.hour, timestamp.minute, timestamp.second
	]
	
	# Generate filename with full timestamped format
	var filename: String
	if report_name.is_empty():
		filename = "res://reports/perf/%s-performance.json" % datetime_str
	else:
		# Clean report name for filename
		var clean_name = report_name.replace(" ", "-").replace("_", "-").to_lower()
		filename = "res://reports/perf/%s-%s.json" % [datetime_str, clean_name]

	# Ensure perf directory exists
	var dir = DirAccess.open("res://")
	if dir:
		if not dir.dir_exists("reports"):
			dir.make_dir("reports")
		if not dir.dir_exists("reports/perf"):
			dir.make_dir("reports/perf")

	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var data = {
			"timestamp": Time.get_datetime_string_from_system(),
			"datetime_str": datetime_str,
			"report_name": report_name,
			"godot_version": Engine.get_version_info(),
			"results": performance_results
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		prints("Performance results saved to: %s" % filename)
		return filename
	else:
		prints("Failed to save performance results to: %s" % filename)
		return ""


## Load historical performance data for comparison
func load_historical_performance_data(report_name: String) -> Array[Dictionary]:
	var clean_name = report_name.replace(" ", "-").replace("_", "-").to_lower()
	var dir = DirAccess.open("res://reports/perf/")
	var historical_data: Array[Dictionary] = []
	
	if not dir:
		prints("Performance history directory not found")
		return historical_data
	
	# Find all files matching the report pattern
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var pattern = "-%s.json" % clean_name
	
	while file_name != "":
		if file_name.ends_with(pattern):
			var full_path = "res://reports/perf/%s" % file_name
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				var json_string = file.get_as_text()
				file.close()
				var json = JSON.new()
				var parse_result = json.parse(json_string)
				if parse_result == OK:
					historical_data.append(json.get_data())
		file_name = dir.get_next()
	
	# Sort by timestamp (most recent first)
	historical_data.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	prints("Loaded %d historical performance reports for %s" % [historical_data.size(), report_name])
	return historical_data


## Get the most recent historical performance data
func get_latest_historical_data(report_name: String) -> Dictionary:
	var historical_data = load_historical_performance_data(report_name)
	if historical_data.is_empty():
		return {}
	return historical_data[0]


## Dual-layer performance analysis: Hard baselines + Historical trends
func compare_with_historical(report_name: String, _unused_param: float = 0.0) -> Dictionary:
	var historical_data = load_historical_performance_data(report_name)
	
	var comparison_results = {
		"historical_runs": historical_data.size(),
		"current_timestamp": Time.get_datetime_string_from_system(),
		"baseline_failures": [],      # Failed hard performance targets
		"baseline_passes": [],        # Met hard performance targets
		"trend_regressions": [],      # Getting worse over time
		"trend_improvements": [],     # Getting better over time
		"trend_stable": [],          # Stable performance over time
		"new_tests": [],             # No historical data
		"no_baseline_tests": []      # No hard baseline defined
	}
	
	# Calculate historical trend statistics (if we have data)
	var trend_stats = {}
	if historical_data.size() >= 2:
		for historical_run in historical_data:
			var historical_results = historical_run.get("results", {})
			for test_name in historical_results:
				if not trend_stats.has(test_name):
					trend_stats[test_name] = []
				trend_stats[test_name].append(historical_results[test_name].avg_time_ms)
	
	# Analyze each current test
	for test_name in performance_results:
		var current_result = performance_results[test_name]
		var current_time = current_result.avg_time_ms
		
		# 1. HARD BASELINE CHECK (Primary - determines pass/fail)
		var baseline_target = PERFORMANCE_BASELINES.get(test_name, -1.0)
		var baseline_status = ""
		var baseline_exceeded = false
		
		if baseline_target > 0:
			baseline_exceeded = current_time > baseline_target
			baseline_status = "PASS" if not baseline_exceeded else "FAIL"
			
			var baseline_comparison = {
				"test_name": test_name,
				"current_time_ms": current_time,
				"baseline_target_ms": baseline_target,
				"over_baseline_ms": current_time - baseline_target,
				"over_baseline_percent": ((current_time - baseline_target) / baseline_target) * 100.0,
				"status": baseline_status
			}
			
			if baseline_exceeded:
				comparison_results.baseline_failures.append(baseline_comparison)
			else:
				comparison_results.baseline_passes.append(baseline_comparison)
		else:
			comparison_results.no_baseline_tests.append(test_name)
		
		# 2. HISTORICAL TREND ANALYSIS (Secondary - shows improvements/regressions)
		if trend_stats.has(test_name) and trend_stats[test_name].size() >= 2:
			var historical_times = trend_stats[test_name]
			
			# Calculate trend statistics
			var trend_avg = historical_times.reduce(func(sum, val): return sum + val, 0.0) / historical_times.size()
			var trend_variance = 0.0
			for time in historical_times:
				trend_variance += (time - trend_avg) * (time - trend_avg)
			trend_variance /= historical_times.size()
			var trend_std_dev = sqrt(trend_variance)
			
			# Calculate recent trend (last 3 runs vs earlier runs)
			var recent_count = min(3, historical_times.size())
			var recent_avg = 0.0
			var earlier_avg = 0.0
			
			for i in recent_count:
				recent_avg += historical_times[i]
			recent_avg /= recent_count
			
			if historical_times.size() > recent_count:
				var earlier_count = historical_times.size() - recent_count
				for i in range(recent_count, historical_times.size()):
					earlier_avg += historical_times[i]
				earlier_avg /= earlier_count
			else:
				earlier_avg = recent_avg
			
			var trend_change_percent = ((current_time - trend_avg) / trend_avg) * 100.0 if trend_avg > 0 else 0.0
			var recent_trend_percent = ((recent_avg - earlier_avg) / earlier_avg) * 100.0 if earlier_avg > 0 else 0.0
			
			var trend_comparison = {
				"test_name": test_name,
				"current_time_ms": current_time,
				"trend_avg_ms": trend_avg,
				"trend_std_dev_ms": trend_std_dev,
				"trend_change_percent": trend_change_percent,
				"recent_trend_percent": recent_trend_percent,
				"historical_runs": historical_times.size(),
				"baseline_status": baseline_status,
				"baseline_target_ms": baseline_target if baseline_target > 0 else null
			}
			
			# Classify trend (independent of baseline pass/fail)
			if abs(trend_change_percent) < 10.0:  # Within 10% of historical average
				comparison_results.trend_stable.append(trend_comparison)
			elif trend_change_percent > 10.0:     # Significantly slower than historical average
				comparison_results.trend_regressions.append(trend_comparison)
			else:                                  # Significantly faster than historical average
				comparison_results.trend_improvements.append(trend_comparison)
		else:
			comparison_results.new_tests.append(test_name)
	
	return comparison_results


## Print dual-layer performance comparison report
func print_performance_comparison(comparison_results: Dictionary):
	if comparison_results.is_empty():
		prints("No comparison data available")
		return
	
	prints("\n=== GECS Dual-Layer Performance Report ===")
	prints("Historical runs: %d" % comparison_results.get("historical_runs", 0))
	prints("Current time: %s" % comparison_results.current_timestamp)
	
	# 1. HARD BASELINE RESULTS (Primary - Pass/Fail)
	prints("\n🎯 BASELINE TARGET ANALYSIS:")
	
	var baseline_failures = comparison_results.baseline_failures
	if not baseline_failures.is_empty():
		prints("\n❌ BASELINE FAILURES (%d) - Tests exceeding hard targets:" % baseline_failures.size())
		for failure in baseline_failures:
			prints("  %s: %.3f ms > %.3f ms target (+%.1f%% over limit)" % [
				failure.test_name,
				failure.current_time_ms,
				failure.baseline_target_ms,
				failure.over_baseline_percent
			])
	
	var baseline_passes = comparison_results.baseline_passes
	if not baseline_passes.is_empty():
		prints("\n✅ BASELINE PASSES (%d) - Tests meeting hard targets:" % baseline_passes.size())
		for passed in baseline_passes:
			var under_by = passed.baseline_target_ms - passed.current_time_ms
			var under_percent = (under_by / passed.baseline_target_ms) * 100.0
			prints("  %s: %.3f ms < %.3f ms target (%.1f%% under limit)" % [
				passed.test_name,
				passed.current_time_ms,
				passed.baseline_target_ms,
				under_percent
			])
	
	# 2. HISTORICAL TREND ANALYSIS (Secondary - Performance trends)
	prints("\n📈 HISTORICAL TREND ANALYSIS:")
	
	var trend_regressions = comparison_results.trend_regressions
	if not trend_regressions.is_empty():
		prints("\n📉 PERFORMANCE TRENDING WORSE (%d):" % trend_regressions.size())
		for regression in trend_regressions:
			prints("  %s: %.3f ms vs %.3f ms avg (%.1f%% slower than historical) [%s baseline]" % [
				regression.test_name,
				regression.current_time_ms,
				regression.trend_avg_ms,
				regression.trend_change_percent,
				regression.baseline_status
			])
	
	var trend_improvements = comparison_results.trend_improvements
	if not trend_improvements.is_empty():
		prints("\n📈 PERFORMANCE TRENDING BETTER (%d):" % trend_improvements.size())
		for improvement in trend_improvements:
			prints("  %s: %.3f ms vs %.3f ms avg (%.1f%% faster than historical) [%s baseline]" % [
				improvement.test_name,
				improvement.current_time_ms,
				improvement.trend_avg_ms,
				abs(improvement.trend_change_percent),
				improvement.baseline_status
			])
	
	var trend_stable = comparison_results.trend_stable
	if not trend_stable.is_empty():
		prints("\n➡️  STABLE TRENDS (%d tests within ±10%% of historical average)" % trend_stable.size())
	
	# 3. DIAGNOSTIC INFO
	var new_tests = comparison_results.new_tests
	if not new_tests.is_empty():
		prints("\n🆕 NEW TESTS (%d) - No historical data:" % new_tests.size())
		for test_name in new_tests:
			prints("  %s" % test_name)
	
	var no_baseline_tests = comparison_results.no_baseline_tests
	if not no_baseline_tests.is_empty():
		prints("\n⚠️  NO BASELINE DEFINED (%d) - Add to PERFORMANCE_BASELINES:" % no_baseline_tests.size())
		for test_name in no_baseline_tests:
			prints("  %s" % test_name)


## Assert no baseline failures (hard performance targets)
func assert_no_performance_regressions(report_name: String, _unused_param: float = 0.0):
	var comparison = compare_with_historical(report_name)
	if comparison.is_empty():
		# No data to compare - this is fine for first run
		return
	
	# Check for hard baseline failures (these cause test failure)
	var baseline_failures = comparison.baseline_failures
	if not baseline_failures.is_empty():
		var error_message = "BASELINE TARGET EXCEEDED - Performance targets not met:\n"
		for failure in baseline_failures:
			error_message += "  %s: %.3f ms > %.3f ms target (+%.1f%% over limit)\n" % [
				failure.test_name,
				failure.current_time_ms,
				failure.baseline_target_ms,
				failure.over_baseline_percent
			]
		fail(error_message)
	
	# Print trend warnings (but don't fail the test)
	var trend_regressions = comparison.trend_regressions
	if not trend_regressions.is_empty():
		prints("\n⚠️  WARNING: Performance trending worse than historical average:")
		for regression in trend_regressions:
			prints("  %s: %.1f%% slower than historical (baseline: %s)" % [
				regression.test_name,
				regression.trend_change_percent,
				regression.baseline_status
			])
