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

func test_all_vs_any_distinct_cache_key():
	var qb_all = world.query.with_all([C_DomainTestA, C_DomainTestB])
	var key_all = qb_all.get_cache_key()
	var qb_any = world.query.with_any([C_DomainTestA, C_DomainTestB])
	var key_any = qb_any.get_cache_key()
	assert_int(key_all).is_not_equal(key_any)

func test_all_vs_mixed_not_colliding():
	var qb1 = world.query.with_all([C_DomainTestA]).with_any([C_DomainTestB])
	var qb2 = world.query.with_all([C_DomainTestA, C_DomainTestB])
	assert_int(qb1.get_cache_key()).is_not_equal(qb2.get_cache_key())

func test_any_vs_exclude_not_colliding():
	var qb3 = world.query.with_any([C_DomainTestA])
	var qb4 = world.query.with_none([C_DomainTestA])
	assert_int(qb3.get_cache_key()).is_not_equal(qb4.get_cache_key())
