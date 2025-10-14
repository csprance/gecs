## Entity Performance Tests
## Tests entity creation, addition, removal, and operations
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


## Test entity creation performance at different scales
func test_entity_creation(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	var time_ms = PerfHelpers.time_it(func():
		for i in scale:
			var entity = auto_free(Entity.new())
			entity.name = "PerfEntity_%d" % i
			entities.append(entity)
	)

	PerfHelpers.record_result("entity_creation", scale, time_ms)


## Test entity creation with multiple components
func test_entity_with_components(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	var time_ms = PerfHelpers.time_it(func():
		for i in scale:
			var entity =  auto_free(Entity.new())
			entity.name = "PerfEntity_%d" % i
			entity.add_component(C_TestA.new())
			entity.add_component(C_TestB.new())
			if i % 2 == 0:
				entity.add_component(C_TestC.new())
			entities.append(entity)
	)

	PerfHelpers.record_result("entity_with_components", scale, time_ms)
	world.purge(false)

## Test adding entities to world
func test_entity_world_addition(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Pre-create entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "PerfEntity_%d" % i
		entities.append(entity)

	# Time just the world addition
	var time_ms = PerfHelpers.time_it(func():
		for entity in entities:
			world.add_entity(entity, null, false)
	)

	PerfHelpers.record_result("entity_world_addition", scale, time_ms)
	world.purge(false)

## Test removing entities from world
func test_entity_removal(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Setup: create and add entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "PerfEntity_%d" % i
		entities.append(entity)
		world.add_entity(entity, null, false)

	# Time removal of half the entities
	var time_ms = PerfHelpers.time_it(func():
		var to_remove = entities.slice(0, scale / 2)
		for entity in to_remove:
			world.remove_entity(entity)
	)

	PerfHelpers.record_result("entity_removal", scale, time_ms)
	world.purge(false)

## Test bulk entity operations
func test_bulk_entity_operations(scale: int, test_parameters := [[100], [1000], [10000]]):
	var entities = []

	# Create batch
	for i in scale:
		var entity = Entity.new()
		entity.name = "BatchEntity_%d" % i
		entities.append(entity)

	# Time bulk addition to world
	var time_ms = PerfHelpers.time_it(func():
		world.add_entities(entities)
	)

	PerfHelpers.record_result("bulk_entity_operations", scale, time_ms)
	world.purge(false)
