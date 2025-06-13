## Performance tests for System processing in GECS
class_name PerformanceTestSystems
extends PerformanceTestBase

var test_world: World
var test_entities: Array[Entity] = []
var test_system: PerformanceTestSystem
var complex_system: ComplexPerformanceTestSystem


func before_test():
	super.before_test()
	test_world = create_test_world()
	test_entities.clear()

	# Create test systems
	test_system = PerformanceTestSystem.new()
	test_system.name = "PerformanceTestSystem"
	complex_system = ComplexPerformanceTestSystem.new()
	complex_system.name = "ComplexPerformanceTestSystem"


func after_test():
	# Clean up test entities
	for entity in test_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	test_entities.clear()

	# Clean up systems
	if test_system and is_instance_valid(test_system):
		test_system.queue_free()
	if complex_system and is_instance_valid(complex_system):
		complex_system.queue_free()

	if test_world:
		test_world.purge()
		test_world = null


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
		test_world.add_entity(entity, null, false)


## Test simple system processing performance
func test_simple_system_processing_small_scale():
	setup_entities_for_systems(SMALL_SCALE)
	test_world.add_system(test_system)
	test_system.reset_count()

	var process_systems = func(): test_world.process(0.016)  # Simulate 60 FPS delta

	benchmark("Simple_System_Processing_Small_Scale", process_systems)
	print_performance_results()

	# Verify system actually processed entities
	assert_that(test_system.process_count).is_greater(0)

	# Assert reasonable performance (should process 100 entities in under 5ms)
	assert_performance_threshold(
		"Simple_System_Processing_Small_Scale", 5.0, "Simple system processing too slow"
	)


func test_simple_system_processing_medium_scale():
	setup_entities_for_systems(MEDIUM_SCALE)
	test_world.add_system(test_system)
	test_system.reset_count()

	var process_systems = func(): test_world.process(0.016)  # Simulate 60 FPS delta

	benchmark("Simple_System_Processing_Medium_Scale", process_systems)
	print_performance_results()

	# Verify system actually processed entities
	assert_that(test_system.process_count).is_greater(0)

	# Assert reasonable performance (should process 1000 entities in under 30ms)
	assert_performance_threshold(
		"Simple_System_Processing_Medium_Scale",
		30.0,
		"Simple system processing too slow at medium scale"
	)


func test_simple_system_processing_large_scale():
	setup_entities_for_systems(LARGE_SCALE)
	test_world.add_system(test_system)
	test_system.reset_count()

	var process_systems = func(): test_world.process(0.016)  # Simulate 60 FPS delta

	benchmark("Simple_System_Processing_Large_Scale", process_systems)
	print_performance_results()

	# Verify system actually processed entities
	assert_that(test_system.process_count).is_greater(0)

	# Assert reasonable performance (should process 10000 entities in under 150ms)
	assert_performance_threshold(
		"Simple_System_Processing_Large_Scale",
		150.0,
		"Simple system processing too slow at large scale"
	)


## Test complex system processing performance
func test_complex_system_processing():
	setup_entities_for_systems(MEDIUM_SCALE)
	test_world.add_system(complex_system)
	complex_system.reset_count()

	var process_complex_systems = func(): test_world.process(0.016)  # Simulate 60 FPS delta

	benchmark("Complex_System_Processing", process_complex_systems)
	print_performance_results()

	# Verify system actually processed entities
	assert_that(complex_system.process_count).is_greater(0)

	# Assert reasonable performance (complex processing should still be under 80ms)
	assert_performance_threshold(
		"Complex_System_Processing", 80.0, "Complex system processing too slow"
	)


## Test multiple systems processing performance
func test_multiple_systems_processing():
	setup_entities_for_systems(MEDIUM_SCALE)

	# Add multiple systems
	test_world.add_system(test_system)
	test_world.add_system(complex_system)
	test_system.reset_count()
	complex_system.reset_count()

	var process_multiple_systems = func(): test_world.process(0.016)  # Process all systems

	benchmark("Multiple_Systems_Processing", process_multiple_systems)
	print_performance_results()

	# Verify both systems processed entities
	assert_that(test_system.process_count).is_greater(0)
	assert_that(complex_system.process_count).is_greater(0)

	# Assert reasonable performance for multiple systems
	assert_performance_threshold(
		"Multiple_Systems_Processing", 120.0, "Multiple systems processing too slow"
	)


## Test system processing with different entity counts
func test_system_processing_scalability():
	var scales = [100, 500, 1000, 2000]

	for scale in scales:
		after_test()
		before_test()

		setup_entities_for_systems(scale)
		test_world.add_system(test_system)
		test_system.reset_count()

		var test_name = "System_Processing_Scale_%d" % scale
		var process_at_scale = func(): test_world.process(0.016)

		benchmark(test_name, process_at_scale)

		# Verify processing happened
		assert_that(test_system.process_count).is_greater(0)

	print_performance_results()

	# Check that performance scales reasonably (not exponentially)
	var scale_100_time = performance_results["System_Processing_Scale_100"].avg_time_ms
	var scale_2000_time = performance_results["System_Processing_Scale_2000"].avg_time_ms

	# 20x entities should not take more than 40x time (allowing for some overhead)
	var max_expected_time = scale_100_time * 40
	assert_that(scale_2000_time).is_less(max_expected_time).override_failure_message(
		(
			"System processing does not scale well: 100 entities=%f ms, 2000 entities=%f ms"
			% [scale_100_time, scale_2000_time]
		)
	)


## Test system processing with no matching entities
func test_system_processing_no_matches():
	# Create entities that don't match our system's query
	for i in MEDIUM_SCALE:
		var entity = Entity.new()
		entity.name = "NoMatchEntity_%d" % i
		entity.add_component(C_TestD.new())  # System queries for C_TestA
		test_entities.append(entity)
		test_world.add_entity(entity, null, false)

	test_world.add_system(test_system)
	test_system.reset_count()

	var process_no_matches = func(): test_world.process(0.016)

	benchmark("System_Processing_No_Matches", process_no_matches)
	print_performance_results()

	# Verify no entities were processed
	assert_that(test_system.process_count).is_equal(0)

	# Should be very fast when no entities match
	assert_performance_threshold(
		"System_Processing_No_Matches", 5.0, "System processing with no matches too slow"
	)


## Test system group processing performance
func test_system_group_processing():
	setup_entities_for_systems(MEDIUM_SCALE)

	# Create systems in different groups
	test_system.group = "physics"
	complex_system.group = "gameplay"

	test_world.add_system(test_system)
	test_world.add_system(complex_system)
	test_system.reset_count()
	complex_system.reset_count()

	var process_physics_group = func(): test_world.process(0.016, "physics")

	var process_gameplay_group = func(): test_world.process(0.016, "gameplay")

	var process_all_groups = func(): test_world.process(0.016)  # No group specified

	benchmark("Physics_Group_Processing", process_physics_group)
	benchmark("Gameplay_Group_Processing", process_gameplay_group)
	benchmark("All_Groups_Processing", process_all_groups)

	print_performance_results()

	# Group processing should be fast
	assert_performance_threshold(
		"Physics_Group_Processing", 50.0, "Physics group processing too slow"
	)
	assert_performance_threshold(
		"Gameplay_Group_Processing", 80.0, "Gameplay group processing too slow"
	)


## Test system processing frequency impact
func test_system_processing_frequency():
	setup_entities_for_systems(SMALL_SCALE)
	test_world.add_system(test_system)

	# Test different processing frequencies
	var single_process = func():
		test_system.reset_count()
		test_world.process(0.016)

	var multiple_process = func():
		test_system.reset_count()
		for i in 10:
			test_world.process(0.016)

	benchmark("Single_Process_Call", single_process)
	benchmark("Multiple_Process_Calls", multiple_process)

	print_performance_results()

	# Multiple calls should scale linearly
	var single_time = performance_results["Single_Process_Call"].avg_time_ms
	var multiple_time = performance_results["Multiple_Process_Calls"].avg_time_ms

	# 10 calls should take roughly 10x time (allowing some overhead)
	var max_expected_time = single_time * 15  # 50% overhead allowance
	assert_that(multiple_time).is_less(max_expected_time).override_failure_message(
		(
			"Multiple system process calls don't scale linearly: single=%f ms, 10x=%f ms"
			% [single_time, multiple_time]
		)
	)


## Test inactive system performance impact
func test_inactive_system_performance():
	setup_entities_for_systems(MEDIUM_SCALE)

	# Add systems and make one inactive
	test_world.add_system(test_system)
	test_world.add_system(complex_system)
	complex_system.active = false  # Disable complex system

	test_system.reset_count()
	complex_system.reset_count()

	var process_with_inactive = func(): test_world.process(0.016)

	benchmark("Processing_With_Inactive_System", process_with_inactive)
	print_performance_results()

	# Only active system should have processed
	assert_that(test_system.process_count).is_greater(0)
	assert_that(complex_system.process_count).is_equal(0)

	# Should be fast (inactive systems shouldn't add overhead)
	assert_performance_threshold(
		"Processing_With_Inactive_System", 40.0, "Processing with inactive system too slow"
	)


## Run all system performance tests
func test_run_all_system_benchmarks():
	test_simple_system_processing_small_scale()
	after_test()
	before_test()

	test_simple_system_processing_medium_scale()
	after_test()
	before_test()

	test_simple_system_processing_large_scale()
	after_test()
	before_test()

	test_complex_system_processing()
	after_test()
	before_test()

	test_multiple_systems_processing()
	after_test()
	before_test()

	test_system_processing_scalability()
	after_test()
	before_test()

	test_system_processing_no_matches()
	after_test()
	before_test()

	test_system_group_processing()
	after_test()
	before_test()

	test_system_processing_frequency()
	after_test()
	before_test()

	test_inactive_system_performance()

	# Save results
	save_performance_results("res://reports/system_performance_results.json")
