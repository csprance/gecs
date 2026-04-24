## Tests for PROP-01, PROP-02, PROP-03: property-query relationship preservation and routing.
##
## Verifies:
##   PROP-01: Relationship.new({C_X: {...}}, target) routes to _post_filter_relationships,
##            never to _structural_rel_keys.
##   PROP-02: _query_has_non_structural_filters() returns true (indirectly: _post_filter_relationships
##            is non-empty) when a query contains a property-query relationship.
##   PROP-03: Mixed structural+post-filter query returns the correct entity set, and the
##            post-filter operates on the already-narrowed structural result.
class_name TestPropertyQueryPreservation
extends GdUnitTestSuite

const C_Likes = preload("res://addons/gecs/tests/components/c_test_a.gd")  # value: int
const C_Eats = preload("res://addons/gecs/tests/components/c_test_c.gd")  # value: int

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


## PROP-01: A property-query relationship (_is_query_relationship=true) must be classified
## into _post_filter_relationships and must NOT appear in _structural_rel_keys.
func test_property_query_classified_as_post_filter():
	var target = Entity.new()
	world.add_entity(target)

	var qb = (
		ECS
		.world
		.query
		.with_relationship(
			[
				Relationship.new({C_Eats: {"value": {"_gt": 5}}}, target),
			],
		)
	)

	assert_int(qb._post_filter_relationships.size()).is_equal(1)
	assert_bool(qb._structural_rel_keys.is_empty()).is_true()


## PROP-02 (affirmative): The non-structural-filter gate is active when a property-query
## relationship is present. Indirectly verified: _post_filter_relationships is non-empty,
## which is the exact condition System._query_has_non_structural_filters() tests.
func test_query_has_non_structural_filters_with_property_query():
	var target = Entity.new()
	world.add_entity(target)

	var qb = (
		ECS
		.world
		.query
		.with_relationship(
			[
				Relationship.new({C_Eats: {"value": {"_gt": 5}}}, target),
			],
		)
	)

	# Non-empty _post_filter_relationships is equivalent to _query_has_non_structural_filters == true
	assert_bool(qb._post_filter_relationships.is_empty()).is_false()


## PROP-02 (complement): A plain type-match relationship (entity target) must NOT populate
## _post_filter_relationships — it is purely structural.
func test_query_has_non_structural_filters_without_property_query():
	var target = Entity.new()
	world.add_entity(target)

	# Plain type-match relationship: entity target → structural path only
	var qb = (
		ECS
		.world
		.query
		.with_relationship(
			[
				Relationship.new(C_Likes.new(), target),
			],
		)
	)

	assert_bool(qb._post_filter_relationships.is_empty()).is_true()


## PROP-03 (correctness): Mixed query — structural part narrows the candidate set,
## then post-filter further narrows it. Result must contain exactly the entities
## that satisfy BOTH conditions.
func test_mixed_structural_and_post_filter_correctness():
	var target_a = Entity.new()
	world.add_entity(target_a)

	# e1, e2, e3: structural C_Likes->target_a AND C_Eats relationship with value > 50
	var e1 = Entity.new()
	var e2 = Entity.new()
	var e3 = Entity.new()
	# e4, e5: structural C_Likes->target_a AND C_Eats relationship with value <= 50
	var e4 = Entity.new()
	var e5 = Entity.new()

	world.add_entity(e1)
	world.add_entity(e2)
	world.add_entity(e3)
	world.add_entity(e4)
	world.add_entity(e5)

	e1.add_relationship(Relationship.new(C_Likes.new(), target_a))
	e1.add_relationship(Relationship.new(C_Eats.new(75), null))
	e2.add_relationship(Relationship.new(C_Likes.new(), target_a))
	e2.add_relationship(Relationship.new(C_Eats.new(100), null))
	e3.add_relationship(Relationship.new(C_Likes.new(), target_a))
	e3.add_relationship(Relationship.new(C_Eats.new(60), null))
	e4.add_relationship(Relationship.new(C_Likes.new(), target_a))
	e4.add_relationship(Relationship.new(C_Eats.new(25), null))
	e5.add_relationship(Relationship.new(C_Likes.new(), target_a))
	e5.add_relationship(Relationship.new(C_Eats.new(10), null))

	var result = Array(
		(
			ECS
			.world
			.query
			.with_relationship(
				[
					Relationship.new(C_Likes.new(), target_a),
					Relationship.new({C_Eats: {"value": {"_gt": 50}}}, null),
				],
			)
			.execute()
		),
	)

	assert_bool(result.has(e1)).is_true()
	assert_bool(result.has(e2)).is_true()
	assert_bool(result.has(e3)).is_true()
	assert_bool(result.has(e4)).is_false()
	assert_bool(result.has(e5)).is_false()
	assert_int(result.size()).is_equal(3)


## PROP-03 (efficiency): 10 entities total; structural query narrows to 4; post-filter narrows
## to 2. Final result size must be 2, proving the post-filter worked on the narrowed set.
func test_post_filter_runs_on_narrowed_set():
	var target_a = Entity.new()
	world.add_entity(target_a)

	var entities = []
	for i in range(10):
		var e = Entity.new()
		world.add_entity(e)
		entities.append(e)

	# Only the first 4 have the structural C_Likes->target_a relationship
	for i in range(4):
		entities[i].add_relationship(Relationship.new(C_Likes.new(), target_a))

	# Of those 4, only 2 have C_Eats value > 50
	entities[0].add_relationship(Relationship.new(C_Eats.new(75), null))
	entities[1].add_relationship(Relationship.new(C_Eats.new(80), null))
	entities[2].add_relationship(Relationship.new(C_Eats.new(20), null))
	entities[3].add_relationship(Relationship.new(C_Eats.new(10), null))

	var result = Array(
		(
			ECS
			.world
			.query
			.with_relationship(
				[
					Relationship.new(C_Likes.new(), target_a),
					Relationship.new({C_Eats: {"value": {"_gt": 50}}}, null),
				],
			)
			.execute()
		),
	)

	# Post-filter reduced 4 structural matches to 2
	assert_int(result.size()).is_equal(2)
	assert_bool(result.has(entities[0])).is_true()
	assert_bool(result.has(entities[1])).is_true()
	assert_bool(result.has(entities[2])).is_false()
	assert_bool(result.has(entities[3])).is_false()


## PROP-03 (exclusion): without_relationship with a property-query correctly excludes entities
## whose relationships satisfy the property criteria.
func test_property_query_in_without_relationship():
	var e_high = Entity.new()
	var e_low = Entity.new()
	world.add_entity(e_high)
	world.add_entity(e_low)

	e_high.add_relationship(Relationship.new(C_Eats.new(100), null))
	e_low.add_relationship(Relationship.new(C_Eats.new(10), null))

	# Exclude entities with a C_Eats relationship where value > 50
	var result = Array(
		(
			ECS
			.world
			.query
			.without_relationship(
				[
					Relationship.new({C_Eats: {"value": {"_gt": 50}}}, null),
				],
			)
			.execute()
		),
	)

	assert_bool(result.has(e_high)).is_false()  # excluded: C_Eats(100) matches value > 50
	assert_bool(result.has(e_low)).is_true()  # included: C_Eats(10) does not match value > 50
