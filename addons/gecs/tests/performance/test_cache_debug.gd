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

## Test to debug cache behavior
func test_cache_hits_with_repeated_queries():
	# Add 100 entities with various components
	for i in 100:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		world.add_entity(entity)

	# Execute same query 10 times and print cache stats each time
	for i in 10:
		var entities = world.query.with_all([C_TestA, C_TestB]).execute()
		var stats = world.get_cache_stats()
		print("Query %d: found %d entities | Cache hits=%d misses=%d" % [
			i + 1,
			entities.size(),
			stats.cache_hits,
			stats.cache_misses
		])
