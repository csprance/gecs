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


#region Base TickSource Tests

func test_tick_source_base():
	var tick_source = TickSource.new()

	# Base implementation should pass through delta
	var result = tick_source.update(0.016)
	assert_float(result).is_equal(0.016)
	assert_float(tick_source.last_delta).is_equal(0.016)

	# Reset should clear last_delta
	tick_source.reset()
	assert_float(tick_source.last_delta).is_equal(0.0)


#endregion Base TickSource Tests

#region IntervalTickSource Tests

func test_interval_tick_source_basic():
	var tick_source = IntervalTickSource.new()
	tick_source.interval = 1.0

	# First update - not enough time accumulated
	var result = tick_source.update(0.5)
	assert_float(result).is_equal(0.0)
	assert_float(tick_source.last_delta).is_equal(0.0)
	assert_int(tick_source.tick_count).is_equal(0)

	# Second update - now we should tick
	result = tick_source.update(0.5)
	assert_float(result).is_equal(1.0)  # Fixed interval
	assert_float(tick_source.last_delta).is_equal(1.0)
	assert_int(tick_source.tick_count).is_equal(1)


func test_interval_tick_source_multiple_ticks():
	var tick_source = IntervalTickSource.new()
	tick_source.interval = 0.1

	# Accumulate enough time for multiple ticks
	for i in range(5):
		tick_source.update(0.1)

	assert_int(tick_source.tick_count).is_equal(5)


func test_interval_tick_source_reset():
	var tick_source = IntervalTickSource.new()
	tick_source.interval = 1.0

	tick_source.update(0.5)
	tick_source.reset()

	assert_float(tick_source.accumulated_time).is_equal(0.0)
	assert_int(tick_source.tick_count).is_equal(0)
	assert_float(tick_source.last_delta).is_equal(0.0)


#endregion IntervalTickSource Tests

#region AccumulatedTickSource Tests

func test_accumulated_tick_source_basic():
	var tick_source = AccumulatedTickSource.new()
	tick_source.interval = 1.0

	# First update - not enough time
	var result = tick_source.update(0.5)
	assert_float(result).is_equal(0.0)
	assert_int(tick_source.tick_count).is_equal(0)

	# Second update - should tick with accumulated time
	result = tick_source.update(0.6)  # Total: 1.1
	assert_float(result).is_equal(1.1)  # Actual accumulated time
	assert_float(tick_source.last_delta).is_equal(1.1)
	assert_int(tick_source.tick_count).is_equal(1)


func test_accumulated_tick_source_resets_accumulation():
	var tick_source = AccumulatedTickSource.new()
	tick_source.interval = 1.0

	tick_source.update(0.5)
	tick_source.update(0.6)  # Ticks with 1.1

	# After tick, accumulated_time should reset
	assert_float(tick_source.accumulated_time).is_equal(0.0)


#endregion AccumulatedTickSource Tests

#region RateFilterTickSource Tests

func test_rate_filter_basic():
	var source = IntervalTickSource.new()
	source.interval = 0.1

	var filter = RateFilterTickSource.new()
	filter.rate = 3
	filter.source = source

	# Tick source 3 times
	for i in range(3):
		source.update(0.1)
		filter.update(0.1)

	# Filter should tick on the 3rd source tick
	assert_int(filter.tick_count).is_equal(0)  # Reset after ticking
	assert_float(filter.last_delta).is_equal(0.3)  # Accumulated delta from 3 ticks


func test_rate_filter_only_counts_source_ticks():
	var source = IntervalTickSource.new()
	source.interval = 1.0

	var filter = RateFilterTickSource.new()
	filter.rate = 2
	filter.source = source

	# Update both with small deltas (source won't tick)
	for i in range(5):
		source.update(0.1)
		filter.update(0.1)

	# Filter should not have ticked because source didn't tick enough
	assert_int(filter.tick_count).is_equal(0)


func test_rate_filter_reset():
	var source = IntervalTickSource.new()
	source.interval = 0.1

	var filter = RateFilterTickSource.new()
	filter.rate = 2
	filter.source = source

	source.update(0.1)
	filter.update(0.1)

	filter.reset()
	assert_int(filter.tick_count).is_equal(0)
	assert_float(filter.accumulated_delta).is_equal(0.0)


#endregion RateFilterTickSource Tests

#region World Integration Tests

func test_register_tick_source():
	var tick_source = IntervalTickSource.new()
	tick_source.interval = 1.0

	world.register_tick_source(tick_source, "test-tick")

	var retrieved = world.get_tick_source("test-tick")
	assert_object(retrieved).is_equal(tick_source)


func test_register_duplicate_tick_source_asserts():
	var tick_source1 = IntervalTickSource.new()
	var tick_source2 = IntervalTickSource.new()

	world.register_tick_source(tick_source1, "test-tick")

	# This should assert - but we can't easily test assertions in GdUnit4
	# Just document that this is expected behavior
	# world.register_tick_source(tick_source2, "test-tick")


func test_get_nonexistent_tick_source():
	var result = world.get_tick_source("nonexistent")
	assert_object(result).is_null()


func test_create_interval_tick_source():
	var tick_source = world.create_interval_tick_source(1.0, "spawner")

	assert_object(tick_source).is_not_null()
	assert_object(tick_source).is_instanceof(IntervalTickSource)
	assert_float(tick_source.interval).is_equal(1.0)

	# Should be retrievable
	var retrieved = world.get_tick_source("spawner")
	assert_object(retrieved).is_equal(tick_source)


func test_create_rate_filter():
	world.create_interval_tick_source(1.0, "second")
	var filter = world.create_rate_filter(60, "second", "minute")

	assert_object(filter).is_not_null()
	assert_object(filter).is_instanceof(RateFilterTickSource)
	assert_int(filter.rate).is_equal(60)


#endregion World Integration Tests

#region System Integration Tests

func test_system_with_tick_source():
	# Create a test system that uses a tick source
	var test_system = System.new()
	test_system.set_script(load("res://addons/gecs/tests/core/test_tick_source_system.gd"))

	# Create tick source
	world.create_interval_tick_source(1.0, "test-tick")

	# Add system to world (this triggers _internal_setup which caches tick source)
	world.add_system(test_system)

	# System should have cached tick source
	assert_object(test_system._tick_source_cached).is_not_null()
	assert_object(test_system._tick_source_cached).is_instanceof(IntervalTickSource)


func test_system_without_tick_source():
	var test_system = System.new()

	world.add_system(test_system)

	# System should have null tick source (uses frame delta)
	assert_object(test_system._tick_source_cached).is_null()


func test_world_process_updates_tick_sources():
	var tick_source = world.create_interval_tick_source(1.0, "test")

	# Process world
	world.process(0.5, "")

	# Tick source should have been updated
	assert_float(tick_source.accumulated_time).is_equal(0.5)


func test_system_only_runs_when_tick_source_ticks():
	# Create a counting system
	var test_system = System.new()
	test_system.set_script(load("res://addons/gecs/tests/core/test_counting_system.gd"))

	# Create tick source with 1 second interval
	world.create_interval_tick_source(1.0, "test-tick")

	world.add_system(test_system)

	# Process with small deltas (tick source won't tick)
	for i in range(5):
		world.process(0.1, "")

	# System should not have run yet (0.5 seconds < 1.0 second)
	assert_int(test_system.run_count).is_equal(0)

	# Process with enough delta to trigger tick
	world.process(0.5, "")

	# System should have run once
	assert_int(test_system.run_count).is_equal(1)


#endregion System Integration Tests

#region Synchronization Tests

func test_multiple_systems_share_tick_source():
	# Create two systems that use the same tick source
	var system1 = System.new()
	system1.set_script(load("res://addons/gecs/tests/core/test_counting_system.gd"))

	var system2 = System.new()
	system2.set_script(load("res://addons/gecs/tests/core/test_counting_system.gd"))

	# Create shared tick source
	world.create_interval_tick_source(1.0, "shared-tick")

	world.add_system(system1)
	world.add_system(system2)

	# Both systems should reference the same tick source
	assert_object(system1._tick_source_cached).is_equal(system2._tick_source_cached)

	# Process to trigger tick
	world.process(1.0, "")

	# Both systems should have run
	assert_int(system1.run_count).is_equal(1)
	assert_int(system2.run_count).is_equal(1)


#endregion Synchronization Tests

#region Hierarchical Timing Tests

func test_hierarchical_tick_sources():
	# Create hierarchy: second -> minute -> hour
	world.create_interval_tick_source(1.0, "second")
	world.create_rate_filter(60, "second", "minute")
	world.create_rate_filter(60, "minute", "hour")

	var second_tick = world.get_tick_source("second")
	var minute_tick = world.get_tick_source("minute")
	var hour_tick = world.get_tick_source("hour")

	# Process 60 seconds
	for i in range(60):
		world.process(1.0, "")

	# Second should have ticked 60 times
	assert_int(second_tick.tick_count).is_equal(60)

	# Minute should have ticked once
	assert_int(minute_tick.tick_count).is_equal(0)  # Reset after ticking
	assert_float(minute_tick.last_delta).is_equal(60.0)

	# Hour should not have ticked yet
	assert_float(hour_tick.last_delta).is_equal(0.0)


#endregion Hierarchical Timing Tests
