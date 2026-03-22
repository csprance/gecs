class_name TestQueryIntegration
extends GdUnitTestSuite
## Test suite for structural relationship query integration.
## Verifies that with_relationship() and without_relationship() resolve via
## archetype cache lookup instead of per-entity scan.
##
## Covers QURY-01 through QURY-06.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## QURY-01: with_relationship() with exact (C_TestA, target_entity) returns only
## entities in the matching archetype bucket (not per-entity scan).
func test_exact_pair_archetype_lookup():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var target = Entity.new()

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(target)

	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())

	# Only entity1 has the relationship
	entity1.add_relationship(Relationship.new(C_TestA.new(), target))

	var result = world.query.with_all([C_TestA]).with_relationship(
		[Relationship.new(C_TestA.new(), target)]
	).execute()

	assert_int(result.size()).is_equal(1)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_false()

	# Verify archetype-level matching: entity1's archetype should have the rel:// slot key
	var archetype1 = world.entity_to_archetype[entity1]
	var expected_key = world._relationship_slot_key(Relationship.new(C_TestA.new(), target))
	var has_expected_key = false
	for rt in archetype1.relationship_types:
		if rt == expected_key:
			has_expected_key = true
			break
	assert_bool(has_expected_key).is_true()


## QURY-02: with_relationship() with null target returns entities via wildcard index.
## Both entities with (C_TestA, target1) and (C_TestA, target2) match a wildcard query.
func test_wildcard_query_via_index():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target1 = Entity.new()
	var target2 = Entity.new()

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(target1)
	world.add_entity(target2)

	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())
	entity3.add_component(C_TestA.new())

	entity1.add_relationship(Relationship.new(C_TestA.new(), target1))
	entity2.add_relationship(Relationship.new(C_TestA.new(), target2))
	# entity3 has no relationships

	var result = world.query.with_relationship(
		[Relationship.new(C_TestA.new(), null)]
	).execute()

	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_false()


## QURY-03a: without_relationship() with exact pair excludes entities structurally.
func test_without_relationship_exact_exclusion():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var target = Entity.new()

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(target)

	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())

	entity1.add_relationship(Relationship.new(C_TestA.new(), target))

	var result = world.query.with_all([C_TestA]).without_relationship(
		[Relationship.new(C_TestA.new(), target)]
	).execute()

	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity1)).is_false()


## QURY-03b: without_relationship() with null target excludes all entities having that
## relation type (wildcard exclusion).
func test_without_relationship_wildcard_exclusion():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var target = Entity.new()

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(target)

	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())

	entity1.add_relationship(Relationship.new(C_TestA.new(), target))

	var result = world.query.with_all([C_TestA]).without_relationship(
		[Relationship.new(C_TestA.new(), null)]
	).execute()

	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity1)).is_false()


## QURY-04: _query_has_non_structural_filters() returns false for type-match
## relationships, true for property-query relationships.
func test_non_structural_filters_classification():
	var target = Entity.new()
	world.add_entity(target)

	# Create a temporary System to test _query_has_non_structural_filters
	var system = System.new()
	system.name = "TestSystem"
	world.add_child(system)

	# Type-match relationship (structural) → false
	var qb_structural = QueryBuilder.new(world)
	qb_structural.with_relationship([Relationship.new(C_TestA.new(), target)])
	assert_bool(system._query_has_non_structural_filters(qb_structural)).is_false()

	# Property-query relationship (non-structural) → true
	var qb_property = QueryBuilder.new(world)
	qb_property.with_relationship([Relationship.new({C_TestA: {"value": {"_gt": 5}}}, target)])
	assert_bool(system._query_has_non_structural_filters(qb_property)).is_true()

	system.queue_free()


## QURY-05: Entity-instance target (GecsFood) matches a query using script-archetype
## target GecsFood via wildcard + post-filter.
func test_script_archetype_subsumption():
	var entity1 = Entity.new()
	var food_entity = GecsFood.new()

	world.add_entity(entity1)
	world.add_entity(food_entity)

	entity1.add_component(C_TestA.new())
	entity1.add_relationship(Relationship.new(C_TestA.new(), food_entity))

	# Query using Script target — should find entity1 via wildcard + post-filter
	var result = world.query.with_all([C_TestA]).with_relationship(
		[Relationship.new(C_TestA.new(), GecsFood)]
	).execute()

	assert_int(result.size()).is_equal(1)
	assert_bool(result.has(entity1)).is_true()


## QURY-06: Cache key includes structural relationships; different relationship pairs
## produce different keys; same pair produces same key.
func test_cache_key_includes_relationships():
	var target1 = Entity.new()
	var target2 = Entity.new()

	world.add_entity(target1)
	world.add_entity(target2)

	var qb1 = QueryBuilder.new(world)
	qb1.with_all([C_TestA]).with_relationship([Relationship.new(C_TestA.new(), target1)])

	var qb2 = QueryBuilder.new(world)
	qb2.with_all([C_TestA]).with_relationship([Relationship.new(C_TestA.new(), target2)])

	var qb3 = QueryBuilder.new(world)
	qb3.with_all([C_TestA]).with_relationship([Relationship.new(C_TestA.new(), target1)])

	var key1 = qb1.get_cache_key()
	var key2 = qb2.get_cache_key()
	var key3 = qb3.get_cache_key()

	# Different pairs → different keys
	assert_int(key1).is_not_equal(key2)
	# Same pair → same key
	assert_int(key1).is_equal(key3)


## QURY-06b: Structural relationship queries are cached — second call hits cache.
func test_structural_relationship_query_cached():
	var entity1 = Entity.new()
	var target = Entity.new()

	world.add_entity(entity1)
	world.add_entity(target)

	entity1.add_component(C_TestA.new())
	entity1.add_relationship(Relationship.new(C_TestA.new(), target))

	world.reset_cache_stats()

	# First call: cache miss
	var result1 = world.query.with_all([C_TestA]).with_relationship(
		[Relationship.new(C_TestA.new(), target)]
	).execute()

	var stats1 = world.get_cache_stats()

	# Second call: should hit cache
	var result2 = world.query.with_all([C_TestA]).with_relationship(
		[Relationship.new(C_TestA.new(), target)]
	).execute()

	var stats2 = world.get_cache_stats()

	assert_int(result1.size()).is_equal(result2.size())
	# Cache hits should increase between first and second call
	assert_int(stats2.cache_hits).is_greater(stats1.cache_hits)
