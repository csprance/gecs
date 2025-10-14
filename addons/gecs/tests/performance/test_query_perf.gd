## Query Performance Tests
## Tests query building and execution performance
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


## Setup diverse entities with various component combinations
func setup_diverse_entities(count: int) -> void:
	for i in count:
		var entity = Entity.new()
		entity.name = "QueryEntity_%d" % i

		# Create diverse component combinations
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		if i % 5 == 0:
			entity.add_component(C_TestC.new())
		if i % 7 == 0:
			entity.add_component(C_TestD.new())

		world.add_entity(entity, null, false)


## Test simple query with_all performance
func test_query_with_all(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_diverse_entities(scale)

	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_all([C_TestA]).execute()
	)

	PerfHelpers.record_result("query_with_all", scale, time_ms)
	world.purge(false)

## Test query with_any performance
func test_query_with_any(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_diverse_entities(scale)

	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_any([C_TestA, C_TestB, C_TestC]).execute()
	)

	PerfHelpers.record_result("query_with_any", scale, time_ms)
	world.purge(false)

## Test query with_none performance
func test_query_with_none(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_diverse_entities(scale)

	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_none([C_TestD]).execute()
	)

	PerfHelpers.record_result("query_with_none", scale, time_ms)
	world.purge(false)

## Test complex combined query
func test_query_complex(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_diverse_entities(scale)

	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query\
			.with_all([C_TestA])\
			.with_any([C_TestB, C_TestC])\
			.with_none([C_TestD])\
			.execute()
	)

	PerfHelpers.record_result("query_complex", scale, time_ms)
	world.purge(false)

## Test query with component query (property filtering)
func test_query_with_component_query(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Setup entities with varying property values
	for i in scale:
		var entity = Entity.new()
		var comp = C_TestA.new()
		comp.value = i
		entity.add_component(comp)
		world.add_entity(entity, null, false)

	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query\
			.with_all([{C_TestA: {'value': {"_gte": scale / 2}}}])\
			.execute()
	)

	PerfHelpers.record_result("query_with_component_query", scale, time_ms)
	world.purge(false)

## Test query caching performance
func test_query_caching(scale: int, test_parameters := [[100], [1000], [10000]]):
	setup_diverse_entities(scale)

	# Execute same query multiple times to test cache
	var time_ms = PerfHelpers.time_it(func():
		for i in 100:
			var entities = world.query.with_all([C_TestA, C_TestB]).execute()
	)

	PerfHelpers.record_result("query_caching", scale, time_ms)
	world.purge(false)

## Test query on empty world
func test_query_empty_world(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Don't setup any entities - testing empty world query

	var time_ms = PerfHelpers.time_it(func():
		for i in scale:
			var entities = world.query.with_all([C_TestA]).execute()
	)

	PerfHelpers.record_result("query_empty_world", scale, time_ms)
	world.purge(false)
