## Regression test suite for Phase 2 cache invalidation bugs.
## CACHE-01: Moving an entity between existing archetypes must NOT wipe the query archetype cache.
## CACHE-02: disable_entity() and enable_entity() must call _invalidate_cache() so queries stay correct.
## CACHE-03: _suppress_invalidation_depth counter field must exist (replaces _should_invalidate_cache bool).
## CACHE-04: End-to-end regression — no stale results after enable/disable or archetype moves.
extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


## CACHE-01: When an entity moves between two archetypes that ALREADY EXIST, the
## query archetype cache should NOT be wiped (cache_invalidated signal delta == 0).
## This FAILS before the fix because _on_entity_component_added unconditionally calls
## _invalidate_cache(), even when no new archetype is created.
func test_cache01_archetype_cache_not_cleared_on_entity_move():
	# Seed both archetypes so they already exist before we start measuring.
	var seed_a = Entity.new()
	seed_a.add_component(C_TestA.new())
	world.add_entity(seed_a)

	var seed_ab = Entity.new()
	seed_ab.add_component(C_TestA.new())
	seed_ab.add_component(C_TestB.new())
	world.add_entity(seed_ab)

	# entity_move will go from archetype-A to archetype-AB (both already exist).
	var entity_move = Entity.new()
	entity_move.add_component(C_TestA.new())
	world.add_entity(entity_move)

	# Wire signal counter AFTER setup so we only capture the move below.
	var signal_count = [0]
	var _handler = func(): signal_count[0] += 1
	world.cache_invalidated.connect(_handler)
	var initial_count = signal_count[0]

	# Move entity from archetype-A to archetype-AB — no NEW archetype is created.
	entity_move.add_component(C_TestB.new())

	# Disconnect to avoid leaking into subsequent tests.
	if world.cache_invalidated.is_connected(_handler):
		world.cache_invalidated.disconnect(_handler)

	# Expect zero full-cache wipes since both archetypes already existed.
	assert_int(signal_count[0] - initial_count).is_equal(0)


## CACHE-02: disable_entity() must emit cache_invalidated so that a persistent
## QueryBuilder (with _cache_valid == true) gets its cache invalidated.
## This FAILS before the fix because disable_entity() never calls _invalidate_cache(),
## so the persistent QueryBuilder never receives the invalidate_cache() callback,
## and returns stale (pre-disable) cached results.
func test_cache02_persistent_query_stale_after_disable():
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)

	# Build a persistent QueryBuilder and connect cache_invalidated to it,
	# exactly as Systems do. This QB will cache its result.
	var persistent_qb = QueryBuilder.new(world)
	persistent_qb.with_all([C_TestA])
	world.cache_invalidated.connect(persistent_qb.invalidate_cache)

	# Prime the QB cache: execute() sets _cache_valid = true.
	var result_before = persistent_qb.execute()
	assert_int(result_before.size()).is_equal(1)
	# Verify _cache_valid is now true (cache was primed).
	assert_bool(persistent_qb._cache_valid).is_true()

	# Disable the entity. Without the fix, this does NOT emit cache_invalidated,
	# so persistent_qb._cache_valid stays true and returns stale results.
	world.disable_entity(entity)

	# The persistent QB must have been invalidated so it returns the updated result.
	# Without the fix, _cache_valid is still true and result is the stale [entity].
	# With the fix, cache_invalidated fires, QB._cache_valid = false, fresh result returned.
	assert_bool(persistent_qb._cache_valid).is_false()

	# Cleanup.
	if world.cache_invalidated.is_connected(persistent_qb.invalidate_cache):
		world.cache_invalidated.disconnect(persistent_qb.invalidate_cache)


## CACHE-03: The depth counter field _suppress_invalidation_depth must exist on World.
## This FAILS before the fix because only _should_invalidate_cache (a bool) exists.
func test_cache03_depth_counter_field_exists():
	# get() returns null when the property does not exist on the object.
	# The field is an int (not an Object), so use assert_that to check for non-null.
	assert_that(world.get("_suppress_invalidation_depth")).is_not_null()


## CACHE-04: disable_entities() batch must emit cache_invalidated exactly ONCE (not once
## per entity). Under the current code without _suppress_invalidation_depth, each
## disable_entity() fires cache_invalidated individually via entity._on_enabled_changed,
## resulting in N emissions instead of 1.
## This FAILS before the fix because the depth counter suppression is not in place —
## disable_entities() is a bare loop with no batch guard.
func test_cache04_disable_entities_batch_single_invalidation():
	# Add three entities so we can disable them as a batch.
	var e1 = Entity.new()
	e1.add_component(C_TestA.new())
	world.add_entity(e1)

	var e2 = Entity.new()
	e2.add_component(C_TestA.new())
	world.add_entity(e2)

	var e3 = Entity.new()
	e3.add_component(C_TestA.new())
	world.add_entity(e3)

	# Wire signal counter AFTER setup.
	var signal_count = [0]
	var _handler = func(): signal_count[0] += 1
	world.cache_invalidated.connect(_handler)
	var initial_count = signal_count[0]

	# Disable all three as a batch — should fire cache_invalidated exactly once.
	world.disable_entities([e1, e2, e3])

	var invalidations = signal_count[0] - initial_count

	if world.cache_invalidated.is_connected(_handler):
		world.cache_invalidated.disconnect(_handler)

	# Without CACHE-03/04 fix: each entity fires individually = 3 invalidations.
	# With fix: depth counter suppresses individual fires, single invalidation at end = 1.
	assert_int(invalidations).is_equal(1)
