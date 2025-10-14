## Component Performance Tests
## Tests component addition, removal, and lookup operations
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


## Test adding components to entities
func test_component_addition(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Pre-create entities
	for i in scale:
		var entity = Entity.new()
		entities.append(entity)
		world.add_entity(entity, null, false)

	# Time component addition
	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			entity.add_component(C_TestA.new())
	)
	
	PerfHelpers.record_result("component_addition", scale, time_ms)
	world.purge(false)


## Test adding multiple components to entities
func test_multiple_component_addition(scale: int, test_parameters := [[100], [1000]]):
	var entities = []

	# Pre-create entities
	for i in scale:
		var entity = Entity.new()
		entities.append(entity)
		world.add_entity(entity, null, false)

	# Time adding multiple components
	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			entity.add_component(C_TestA.new())
			entity.add_component(C_TestB.new())
			entity.add_component(C_TestC.new())
	)

	PerfHelpers.record_result("multiple_component_addition", scale, time_ms)
	world.purge(false)

## Test removing components from entities
func test_component_removal(scale: int, test_parameters := [[100], [1000]]):
	var entities = []

	# Setup: create entities with components
	for i in scale:
		var entity = Entity.new()
		entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())
		entities.append(entity)
		world.add_entity(entity, null, false)

	# Time component removal
	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			entity.remove_component(C_TestA)
	)

	PerfHelpers.record_result("component_removal", scale, time_ms)
	world.purge(false)

## Test component lookup (has_component)
func test_component_lookup(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Setup: create entities with components
	for i in scale:
		var entity = Entity.new()
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())
		entities.append(entity)
		world.add_entity(entity, null, false)

	# Time component lookups
	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			var has_a = entity.has_component(C_TestA)
			var has_b = entity.has_component(C_TestB)
	)

	PerfHelpers.record_result("component_lookup", scale, time_ms)
	world.purge(false)

## Test getting component from entity
func test_component_get(scale: int, test_parameters := [[100], [1000]]):
	var entities = []

	# Setup: create entities with components
	for i in scale:
		var entity = Entity.new()
		entity.add_component(C_TestA.new())
		entity.add_component(C_TestB.new())
		entities.append(entity)
		world.add_entity(entity, null, false)

	# Time component retrieval
	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			var comp_a = entity.get_component(C_TestA)
			var comp_b = entity.get_component(C_TestB)
	)

	PerfHelpers.record_result("component_get", scale, time_ms)
	world.purge(false)
