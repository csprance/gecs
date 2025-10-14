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

## Test that disabled entities don't contribute to query time
## Creates many disabled entities with only a few enabled ones
## Query time should be similar to querying with only the enabled count
func test_query_disabled_entities_no_impact(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Create mostly disabled entities
	var enabled_count = 10  # Always use 10 enabled entities regardless of scale

	# First, create disabled entities (scale - enabled_count)
	for i in (scale - enabled_count):
		var entity = Entity.new()
		entity.name = "DisabledEntity_%d" % i
		entity.enabled = false
		entity.add_component(C_TestA.new())
		world.add_entity(entity, null, false)

	# Then create the few enabled entities
	for i in enabled_count:
		var entity = Entity.new()
		entity.name = "EnabledEntity_%d" % i
		entity.enabled = true
		entity.add_component(C_TestA.new())
		world.add_entity(entity, null, false)

	# Time querying only enabled entities
	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_all([C_TestA]).enabled().execute()
	)

	PerfHelpers.record_result("query_disabled_entities_no_impact", scale, time_ms)
	world.purge(false)

## Baseline test: query with only enabled entities (no disabled ones)
## This should have similar performance to test_query_disabled_entities_no_impact
func test_query_only_enabled_baseline(scale: int, test_parameters := [[100], [1000], [10000]]):
	var enabled_count = 10  # Same as test_query_disabled_entities_no_impact

	# Create only enabled entities
	for i in enabled_count:
		var entity = Entity.new()
		entity.name = "EnabledEntity_%d" % i
		entity.enabled = true
		entity.add_component(C_TestA.new())
		world.add_entity(entity, null, false)

	# Time querying enabled entities
	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_all([C_TestA]).enabled().execute()
	)

	PerfHelpers.record_result("query_only_enabled_baseline", scale, time_ms)
	world.purge(false)

## Test group query performance using Godot's optimized get_nodes_in_group()
## This should be very fast since it uses Godot's native group indexing
func test_query_with_group(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Create entities and add them to a group
	for i in scale:
		var entity = Entity.new()
		entity.name = "GroupEntity_%d" % i
		entity.add_component(C_TestA.new())
		world.add_entity(entity, null, true)  # Must be in tree for groups
		entity.add_to_group("test_group")

	# Time querying by group
	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_group(["test_group"]).execute()
	)

	PerfHelpers.record_result("query_with_group", scale, time_ms)
	world.purge(false)

## Test group query combined with component filtering
## This tests the common case of filtering entities by both group and components
func test_query_group_with_components(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Create diverse entities in a group
	for i in scale:
		var entity = Entity.new()
		entity.name = "GroupEntity_%d" % i

		# Add various components
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())

		world.add_entity(entity, null, true)  # Must be in tree for groups
		entity.add_to_group("test_group")

	# Time querying by group + components
	var time_ms = PerfHelpers.time_it(func():
		var entities = world.query.with_group(["test_group"]).with_all([C_TestA]).execute()
	)

	PerfHelpers.record_result("query_group_with_components", scale, time_ms)
	world.purge(false)
