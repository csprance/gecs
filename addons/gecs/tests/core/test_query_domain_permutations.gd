extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World

# Preload component scripts to ensure availability
const C_PermA = preload("res://addons/gecs/tests/components/c_perm_a.gd")
const C_PermB = preload("res://addons/gecs/tests/components/c_perm_b.gd")
const C_PermC = preload("res://addons/gecs/tests/components/c_perm_c.gd")
const C_PermD = preload("res://addons/gecs/tests/components/c_perm_d.gd")
const C_PermE = preload("res://addons/gecs/tests/components/c_perm_e.gd")
const C_PermF = preload("res://addons/gecs/tests/components/c_perm_f.gd")

const ALL = [C_PermA, C_PermB]
const ANY = [C_PermC, C_PermD]
const NONE = [C_PermE, C_PermF]

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	if world:
		world.purge(false)

func _both_orders(arr: Array) -> Array:
	if arr.size() < 2:
		return [arr]
	var rev = arr.duplicate(); rev.reverse()
	return [arr, rev]

func _cache_key(all: Array, any: Array, none: Array) -> int:
	return world.query.with_all(all).with_any(any).with_none(none).get_cache_key()

func test_permutation_invariance_all_any_none():
	var keys = []
	for all_var in _both_orders(ALL):
		for any_var in _both_orders(ANY):
			for none_var in _both_orders(NONE):
				keys.append(_cache_key(all_var, any_var, none_var))
	var first = keys[0]
	for k in keys:
		assert_int(k).is_equal(first)

func test_cross_domain_differentiation():
	var k1 = _cache_key([C_PermA, C_PermB], [C_PermC, C_PermD], [C_PermE, C_PermF])
	# Move C_PermB to ANY domain should change key
	var k2 = _cache_key([C_PermA], [C_PermB, C_PermC, C_PermD], [C_PermE, C_PermF])
	assert_int(k1).is_not_equal(k2)

func test_empty_domain_variants_unique():
	var k_all_only = world.query.with_all([C_PermA, C_PermB]).get_cache_key()
	var k_any_only = world.query.with_any([C_PermA, C_PermB]).get_cache_key()
	var k_none_only = world.query.with_none([C_PermA, C_PermB]).get_cache_key()
	assert_int(k_all_only).is_not_equal(k_any_only)
	assert_int(k_all_only).is_not_equal(k_none_only)
	assert_int(k_any_only).is_not_equal(k_none_only)

func test_domain_swaps_stability():
	# Swapping order inside a single domain should not change key
	var k_orig = _cache_key(ALL, ANY, NONE)
	var all_rev = ALL.duplicate(); all_rev.reverse()
	var any_rev = ANY.duplicate(); any_rev.reverse()
	var none_rev = NONE.duplicate(); none_rev.reverse()
	var k_rev_combo = _cache_key(all_rev, any_rev, none_rev)
	assert_int(k_orig).is_equal(k_rev_combo)

func test_single_component_domains_invariance():
	# Reduce domains to single components, permutations collapse
	var k1 = _cache_key([C_PermA], [C_PermC], [C_PermE])
	var k2 = _cache_key([C_PermA], [C_PermC], [C_PermE])
	assert_int(k1).is_equal(k2)

func test_mixed_add_remove_domain_changes():
	# Adding a component to ANY changes key; removing restores original
	var base = _cache_key(ALL, [C_PermC], NONE)
	var added = _cache_key(ALL, [C_PermC, C_PermD], NONE)
	assert_int(base).is_not_equal(added)
	var restored = _cache_key(ALL, [C_PermC], NONE)
	assert_int(restored).is_equal(base)
