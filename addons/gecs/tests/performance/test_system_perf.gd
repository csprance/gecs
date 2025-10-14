## System Performance Tests
## Tests system processing and entity iteration performance
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


## Setup entities for system testing
func setup_entities_for_systems(count: int) -> void:
	for i in count:
		var entity = Entity.new()
		entity.name = "SystemEntity_%d" % i
		entity.add_component(C_TestA.new())
		if i % 2 == 0:
			entity.add_component(C_TestB.new())
		if i % 4 == 0:
			entity.add_component(C_TestC.new())
		world.add_entity(entity, null, false)


## Test simple system processing
func test_system_processing(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_entities_for_systems(scale)

	var test_system = PerformanceTestSystem.new()
	world.add_system(test_system)

	var time_ms = PerfHelpers.time_it(func():
		world.process(0.016)  # 60 FPS delta
	)

	PerfHelpers.record_result("system_processing", scale, time_ms)
	world.purge(false)

## Test multiple systems processing
func test_multiple_systems(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_entities_for_systems(scale)

	var system_a = PerformanceTestSystem.new()
	var system_b = ComplexPerformanceTestSystem.new()
	world.add_systems([system_a, system_b])

	var time_ms = PerfHelpers.time_it(func():
		world.process(0.016)
	)

	PerfHelpers.record_result("multiple_systems", scale, time_ms)
	world.purge(false)

## Test system processing with no matches
func test_system_no_matches(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_entities_for_systems(scale)

	# Create system that won't match any entities
	var test_system = PerformanceTestSystem.new()
	world.add_system(test_system)

	# Remove all C_TestA components so system doesn't match
	for entity in world.entities:
		entity.remove_component(C_TestA)

	var time_ms = PerfHelpers.time_it(func():
		world.process(0.016)
	)

	PerfHelpers.record_result("system_no_matches", scale, time_ms)
	world.purge(false)

## Test system processing with different groups
func test_system_groups(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_entities_for_systems(scale)

	var physics_system = PerformanceTestSystem.new()
	physics_system.group = "physics"
	var render_system = PerformanceTestSystem.new()
	render_system.group = "render"

	world.add_systems([physics_system, render_system])

	var time_ms = PerfHelpers.time_it(func():
		world.process(0.016, "physics")
		world.process(0.016, "render")
	)

	PerfHelpers.record_result("system_groups", scale, time_ms)
	world.purge(false)

## Test system processing with entity changes mid-frame
func test_system_dynamic_entities(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Start with half the entities
	setup_entities_for_systems(scale / 2)

	var test_system = PerformanceTestSystem.new()
	world.add_system(test_system)

	var time_ms = PerfHelpers.time_it(func():
		# Process
		world.process(0.016)

		# Add more entities mid-frame
		for i in range(scale / 2, scale):
			var entity = Entity.new()
			entity.add_component(C_TestA.new())
			world.add_entity(entity, null, false)

		# Process again with more entities
		world.process(0.016)
	)

	PerfHelpers.record_result("system_dynamic_entities", scale, time_ms)
	world.purge(false)
