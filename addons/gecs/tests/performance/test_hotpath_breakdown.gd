## System Processing Hotpath Breakdown Tests
## Detailed profiling of where time is spent during system processing
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


## Setup entities with velocity components (like real example)
func setup_velocity_entities(count: int) -> void:
	for i in count:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		entity.add_component(C_Velocity.new(Vector3(randf(), randf(), randf())))
		world.add_entity(entity, null, false)


## Test 1: Pure query execution (no processing)
func test_query_execution_only(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_velocity_entities(scale)

	var time_ms = PerfHelpers.time_it(func():
		var _result = world.query.with_all([C_Velocity]).execute()
	)

	PerfHelpers.record_result("hotpath_query_execution", scale, time_ms)
	world.purge(false)


## Test 2: Query + component access (no actual work)
func test_component_access(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_velocity_entities(scale)

	var entities = world.query.with_all([C_Velocity]).execute()
	var c_velocity_path = C_Velocity.resource_path

	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			var _component = entity.components.get(c_velocity_path, null) as C_Velocity
	)

	PerfHelpers.record_result("hotpath_component_access", scale, time_ms)
	world.purge(false)


## Test 3: Query + component access + data read
func test_component_data_read(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_velocity_entities(scale)

	var entities = world.query.with_all([C_Velocity]).execute()
	var c_velocity_path = C_Velocity.resource_path

	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			var component = entity.components.get(c_velocity_path, null) as C_Velocity
			if component:
				# Read the velocity data
				var _vel = component.velocity
	)

	PerfHelpers.record_result("hotpath_data_read", scale, time_ms)
	world.purge(false)


## Test 4: Simulate full system processing loop (manual)
func test_simulated_system_loop(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_velocity_entities(scale)

	var c_velocity_path = C_Velocity.resource_path
	var delta = 0.016

	var time_ms = PerfHelpers.time_it(func():
		# Simulate what a system does: query + iterate + component access + work
		var entities = world.query.with_all([C_Velocity]).execute()
		for entity in entities:
			var component = entity.components.get(c_velocity_path, null) as C_Velocity
			if component:
				# Simulate typical work (reading velocity, calculating new position)
				var _new_pos = component.velocity * delta
	)

	PerfHelpers.record_result("hotpath_simulated_system", scale, time_ms)
	world.purge(false)


## Test 5: Using actual PerformanceTestSystem (available in tests)
func test_actual_system_processing(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Use C_TestA instead since PerformanceTestSystem uses it
	for i in scale:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		entity.add_component(C_TestA.new())
		world.add_entity(entity, null, false)

	var test_system = PerformanceTestSystem.new()
	world.add_system(test_system)

	var time_ms = PerfHelpers.time_it(func():
		world.process(0.016)
	)

	PerfHelpers.record_result("hotpath_actual_system", scale, time_ms)
	world.purge(false)


## Test 6: Multiple query executions per frame (simulating multiple systems)
func test_multiple_queries_per_frame(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_velocity_entities(scale)

	# Add multiple components to entities
	for entity in world.entities:
		entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())

	var time_ms = PerfHelpers.time_it(func():
		var _r1 = world.query.with_all([C_Velocity]).execute()
		var _r2 = world.query.with_all([C_TestA]).execute()
		var _r3 = world.query.with_all([C_TestB]).execute()
	)

	PerfHelpers.record_result("hotpath_multiple_queries", scale, time_ms)
	world.purge(false)


## Test 7: Component access patterns - dictionary vs cached path
func test_component_access_patterns(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_velocity_entities(scale)

	var entities = world.query.with_all([C_Velocity]).execute()

	# Test with cached path (current best practice)
	var c_velocity_path = C_Velocity.resource_path
	var time_cached = PerfHelpers.time_it(func():
		for entity in entities:
			var _component = entity.components.get(c_velocity_path, null) as C_Velocity
	)

	# Test with get_component() helper
	var time_helper = PerfHelpers.time_it(func():
		for entity in entities:
			var _component = entity.get_component(C_Velocity)
	)

	PerfHelpers.record_result("hotpath_component_access_cached", scale, time_cached)
	PerfHelpers.record_result("hotpath_component_access_helper", scale, time_helper)
	world.purge(false)
