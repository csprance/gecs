extends GdUnitTestSuite

# Verifies that with_all([...]) matches entities regardless of component order both in
# entity component-add order and query component array order. Uses 15 distinct component types.

var runner: GdUnitSceneRunner
var world: World

var ALL_COMPONENT_TYPES = [
	C_OrderTestA, C_OrderTestB, C_OrderTestC, C_OrderTestD, C_OrderTestE,
	C_OrderTestF, C_OrderTestG, C_OrderTestH, C_OrderTestI, C_OrderTestJ,
	C_OrderTestK, C_OrderTestL, C_OrderTestM, C_OrderTestN, C_OrderTestO
]

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	if world:
		world.purge(false)

func _make_entity_with_components(order: Array) -> Entity:
	var e = Entity.new()
	for comp_type in order:
		var comp = comp_type.new()
		e.add_component(comp)
	return e

func test_with_all_order_independent():
	# Create entities with different component insertion orders
	var shuffled1 = ALL_COMPONENT_TYPES.duplicate()
	shuffled1.shuffle()
	var shuffled2 = ALL_COMPONENT_TYPES.duplicate()
	shuffled2.shuffle()
	var shuffled3 = ALL_COMPONENT_TYPES.duplicate()
	shuffled3.shuffle()

	var e1 = _make_entity_with_components(shuffled1)
	var e2 = _make_entity_with_components(shuffled2)
	var e3 = _make_entity_with_components(shuffled3)
	world.add_entities([e1, e2, e3])

	# Build multiple queries with different ordering of with_all component arrays
	var q_base = world.query.with_all(ALL_COMPONENT_TYPES).execute()
	var rev = ALL_COMPONENT_TYPES.duplicate()
	rev.reverse()
	var q_rev = world.query.with_all(rev).execute()
	var alt = ALL_COMPONENT_TYPES.duplicate(); alt.shuffle()
	var q_alt = world.query.with_all(alt).execute()

	# All queries should match all entities
	assert_int(q_base.size()).is_equal(3)
	assert_int(q_rev.size()).is_equal(3)
	assert_int(q_alt.size()).is_equal(3)

	# Ensure same entity set (order may differ). Convert to Set of instance IDs.
	var set_base = q_base.map(func(e): return e.get_instance_id())
	var set_rev = q_rev.map(func(e): return e.get_instance_id())
	var set_alt = q_alt.map(func(e): return e.get_instance_id())
	set_base.sort(); set_rev.sort(); set_alt.sort()
	assert_array(set_base).is_equal(set_rev)
	assert_array(set_base).is_equal(set_alt)

func test_cache_key_consistency():
	# Verify cache key identical for different ordering
	var qb1 = QueryBuilder.new(world).with_all(ALL_COMPONENT_TYPES.duplicate())
	var key1 = qb1.get_cache_key()
	var rev2 = ALL_COMPONENT_TYPES.duplicate()
	rev2.reverse()
	var qb2 = QueryBuilder.new(world).with_all(rev2)
	var key2 = qb2.get_cache_key()
	var shuffled = ALL_COMPONENT_TYPES.duplicate(); shuffled.shuffle()
	var qb3 = QueryBuilder.new(world).with_all(shuffled)
	var key3 = qb3.get_cache_key()
	assert_int(key1).is_equal(key2)
	assert_int(key1).is_equal(key3)
