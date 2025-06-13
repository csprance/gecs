## Master performance test suite for GECS
## Runs all performance tests and generates comprehensive reports
extends PerformanceTestBase


## Quick smoke test to verify performance is reasonable
func test_performance_smoke_test():
	print("\n--- QUICK PERFORMANCE SMOKE TEST ---")

	# Run a minimal set of tests to quickly verify performance is reasonable
	var world = create_test_world()
	var entities = create_test_entities(100, world)

	# Quick query test
	var query_time = measure_time(
		func():
			var results = world.query.with_all([C_TestA]).execute()
			assert_that(results.size()).is_greater(0)
	)

	# Quick system processing test
	var system = PerformanceTestSystem.new()
	world.add_system(system)
	var system_time = measure_time(func(): world.process(0.016))

	print("Query Time: %.3f ms" % query_time)
	print("System Processing Time: %.3f ms" % system_time)

	# Basic performance assertions
	assert_that(query_time).is_less(10.0).override_failure_message(
		"Basic query too slow: %f ms" % query_time
	)
	assert_that(system_time).is_less(5.0).override_failure_message(
		"Basic system processing too slow: %f ms" % system_time
	)

	# Cleanup
	world.purge()
	system.queue_free()

	print("Performance smoke test passed")


## Performance regression test against baseline
func test_performance_regression_check():
	print("\n--- PERFORMANCE REGRESSION CHECK ---")
	
	# Simple baseline comparison using current smoke test
	var world = create_test_world()
	var entities = create_test_entities(1000, world)
	
	var query_time = measure_time(
		func():
			var results = world.query.with_all([C_TestA]).execute()
			assert_that(results.size()).is_greater(0)
	)
	
	# Assert against reasonable baseline thresholds
	assert_that(query_time).is_less(50.0).override_failure_message(
		"Query performance regression detected: %f ms" % query_time
	)
	
	world.purge()
	print("Performance regression check passed")
