class_name TestCodexReviewFixes
extends GdUnitTestSuite
## Tests for bugs identified by Codex review:
## 1. Exact relationship exclusions over-matching (P1)
## 2. Cache invalidation missing in batch relationship moves (P1)
## 3. Per-relationship signals missing from batch helpers (P1)
## 4. Relationship keys missing in batched component operations (P2)

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


#region P1: Exact relationship exclusion over-matching


## without_relationship with a specific target must NOT exclude entities that
## have the same relation type pointing to a DIFFERENT target.
func test_without_relationship_exact_target_does_not_exclude_other_targets():
	var entity_a = Entity.new()
	var entity_b = Entity.new()
	var target_a = Entity.new()
	var target_b = Entity.new()

	world.add_entity(entity_a)
	world.add_entity(entity_b)
	world.add_entity(target_a)
	world.add_entity(target_b)

	entity_a.add_component(C_TestA.new())
	entity_b.add_component(C_TestA.new())

	# entity_a likes target_a, entity_b likes target_b
	entity_a.add_relationship(Relationship.new(C_TestB.new(), target_a))
	entity_b.add_relationship(Relationship.new(C_TestB.new(), target_b))

	# Exclude entities that like target_a — entity_b should still be found
	var result = (
		world
		.query
		.with_all([C_TestA])
		.without_relationship(
			[Relationship.new(C_TestB.new(), target_a)],
		)
		.execute()
	)

	assert_int(result.size()).is_equal(1)
	assert_object(result[0]).is_same(entity_b)


## Wildcard exclusion (null target) should still exclude all targets of that type.
func test_without_relationship_wildcard_excludes_all_targets():
	var entity_a = Entity.new()
	var entity_b = Entity.new()
	var target = Entity.new()

	world.add_entity(entity_a)
	world.add_entity(entity_b)
	world.add_entity(target)

	entity_a.add_component(C_TestA.new())
	entity_b.add_component(C_TestA.new())

	entity_a.add_relationship(Relationship.new(C_TestB.new(), target))

	# Wildcard exclusion: exclude any entity with ANY C_TestB relationship
	var result = (
		world
		.query
		.with_all([C_TestA])
		.without_relationship(
			[Relationship.new(C_TestB.new(), null)],
		)
		.execute()
	)

	assert_int(result.size()).is_equal(1)
	assert_object(result[0]).is_same(entity_b)


#endregion

#region P1: Cache invalidation in batch relationship moves


## After batch relationship addition, queries must reflect the change immediately.
func test_batch_add_relationships_invalidates_cache():
	var entity = Entity.new()
	var target_a = Entity.new()
	var target_b = Entity.new()

	world.add_entity(entity)
	world.add_entity(target_a)
	world.add_entity(target_b)

	entity.add_component(C_TestA.new())

	# Pre-query to populate cache
	var before = (
		world
		.query
		.with_all([C_TestA])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target_a)],
		)
		.execute()
	)
	assert_int(before.size()).is_equal(0)

	# Batch add relationships
	(
		entity
		.add_relationships(
			[
				Relationship.new(C_TestB.new(), target_a),
				Relationship.new(C_TestB.new(), target_b),
			],
		)
	)

	# Query should now find the entity (cache must be invalidated)
	var after = (
		world
		.query
		.with_all([C_TestA])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target_a)],
		)
		.execute()
	)
	assert_int(after.size()).is_equal(1)
	assert_object(after[0]).is_same(entity)


## After batch relationship removal, queries must reflect the change immediately.
func test_batch_remove_relationships_invalidates_cache():
	var entity = Entity.new()
	var target_a = Entity.new()
	var target_b = Entity.new()

	world.add_entity(entity)
	world.add_entity(target_a)
	world.add_entity(target_b)

	entity.add_component(C_TestA.new())
	entity.add_relationship(Relationship.new(C_TestB.new(), target_a))
	entity.add_relationship(Relationship.new(C_TestB.new(), target_b))

	# Pre-query to populate cache
	var before = (
		world
		.query
		.with_all([C_TestA])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target_a)],
		)
		.execute()
	)
	assert_int(before.size()).is_equal(1)

	# Batch remove
	(
		entity
		.remove_relationships(
			[
				Relationship.new(C_TestB.new(), target_a),
				Relationship.new(C_TestB.new(), target_b),
			],
		)
	)

	# Query should no longer find the entity
	var after = (
		world
		.query
		.with_all([C_TestA])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target_a)],
		)
		.execute()
	)
	assert_int(after.size()).is_equal(0)


#endregion

#region P1: Per-relationship signals from batch helpers


## add_relationships() must emit per-relationship entity signals for external listeners.
func test_batch_add_emits_per_entity_signals():
	var entity = Entity.new()
	var target_a = Entity.new()
	var target_b = Entity.new()

	world.add_entity(entity)
	world.add_entity(target_a)
	world.add_entity(target_b)

	var received_additions: Array = []
	entity.relationship_added.connect(func(_e, rel): received_additions.append(rel))

	(
		entity
		.add_relationships(
			[
				Relationship.new(C_TestA.new(), target_a),
				Relationship.new(C_TestB.new(), target_b),
			],
		)
	)

	assert_int(received_additions.size()).is_equal(2)


## remove_relationships() must emit per-relationship entity signals for external listeners.
func test_batch_remove_emits_per_entity_signals():
	var entity = Entity.new()
	var target_a = Entity.new()
	var target_b = Entity.new()

	world.add_entity(entity)
	world.add_entity(target_a)
	world.add_entity(target_b)

	var rel_a = Relationship.new(C_TestA.new(), target_a)
	var rel_b = Relationship.new(C_TestB.new(), target_b)
	entity.add_relationship(rel_a)
	entity.add_relationship(rel_b)

	var received_removals: Array = []
	entity.relationship_removed.connect(func(_e, rel): received_removals.append(rel))

	(
		entity
		.remove_relationships(
			[
				Relationship.new(C_TestA.new(), target_a),
				Relationship.new(C_TestB.new(), target_b),
			],
		)
	)

	assert_int(received_removals.size()).is_equal(2)


## Batch operations must still perform only a single archetype transition
## (not N individual transitions).
func test_batch_add_single_archetype_transition():
	var entity = Entity.new()
	var target_a = Entity.new()
	var target_b = Entity.new()

	world.add_entity(entity)
	world.add_entity(target_a)
	world.add_entity(target_b)

	entity.add_component(C_TestA.new())

	var old_archetype = world.entity_to_archetype[entity]

	(
		entity
		.add_relationships(
			[
				Relationship.new(C_TestB.new(), target_a),
				Relationship.new(C_TestC.new(), target_b),
			],
		)
	)

	var new_archetype = world.entity_to_archetype[entity]
	assert_object(new_archetype).is_not_same(old_archetype)
	# Should have both relationship types
	assert_bool(new_archetype.relationship_types.size() >= 2).is_true()


#endregion

#region P2: Relationship keys in batched component operations


## add_components() on an entity WITH relationships must include rel:// keys
## in the new archetype.
func test_add_components_preserves_relationship_keys():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	# Start with a relationship
	entity.add_component(C_TestA.new())
	entity.add_relationship(Relationship.new(C_TestB.new(), target))

	var arch_before = world.entity_to_archetype[entity]
	assert_bool(arch_before.relationship_types.size() > 0).is_true()

	# Batch-add a new component — archetype should still have rel:// keys
	entity.add_components([C_TestC.new()])

	var arch_after = world.entity_to_archetype[entity]
	assert_bool(arch_after.relationship_types.size() > 0).is_true()

	# Relationship query should still find the entity
	var result = (
		world
		.query
		.with_all([C_TestA, C_TestC])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target)],
		)
		.execute()
	)
	assert_int(result.size()).is_equal(1)


## remove_components() on an entity WITH relationships must include rel:// keys
## in the new archetype.
func test_remove_components_preserves_relationship_keys():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	entity.add_component(C_TestA.new())
	entity.add_component(C_TestC.new())
	entity.add_relationship(Relationship.new(C_TestB.new(), target))

	var arch_before = world.entity_to_archetype[entity]
	assert_bool(arch_before.relationship_types.size() > 0).is_true()

	# Batch-remove a component — archetype should still have rel:// keys
	entity.remove_components([C_TestC])

	var arch_after = world.entity_to_archetype[entity]
	assert_bool(arch_after.relationship_types.size() > 0).is_true()

	# Relationship query should still find the entity
	var result = (
		world
		.query
		.with_all([C_TestA])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target)],
		)
		.execute()
	)
	assert_int(result.size()).is_equal(1)


#endregion

#region Regression: combine() must reclassify relationship buckets


## When two QueryBuilders are combined, the structural/wildcard/post-filter
## classification arrays must be rebuilt so that relationship queries work
## through the archetype path rather than being silently dropped.
func test_combine_reclassifies_relationship_buckets():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	entity.add_component(C_TestA.new())
	entity.add_relationship(Relationship.new(C_TestB.new(), target))

	# Build two separate queries and combine them
	var q1 = QueryBuilder.new()
	q1.set_world(world)
	q1.with_all([C_TestA])

	var q2 = QueryBuilder.new()
	q2.set_world(world)
	q2.with_relationship([Relationship.new(C_TestB.new(), target)])

	q1.combine(q2)
	var result = q1.execute()

	# Must find the entity — combine() must reclassify relationships
	assert_int(result.size()).is_equal(1)
	assert_object(result[0]).is_same(entity)


## Combined query with without_relationship must also reclassify exclusion buckets.
func test_combine_reclassifies_exclusion_relationship_buckets():
	var entity_a = Entity.new()
	var entity_b = Entity.new()
	var target = Entity.new()

	world.add_entity(entity_a)
	world.add_entity(entity_b)
	world.add_entity(target)

	entity_a.add_component(C_TestA.new())
	entity_b.add_component(C_TestA.new())
	entity_a.add_relationship(Relationship.new(C_TestB.new(), target))

	var q1 = QueryBuilder.new()
	q1.set_world(world)
	q1.with_all([C_TestA])

	var q2 = QueryBuilder.new()
	q2.set_world(world)
	q2.without_relationship([Relationship.new(C_TestB.new(), target)])

	q1.combine(q2)
	var result = q1.execute()

	# Must exclude entity_a (has the relationship), keep entity_b
	assert_int(result.size()).is_equal(1)
	assert_object(result[0]).is_same(entity_b)


#endregion

#region Regression: purge(keep) must not reset _next_entity_id


## When purging with a keep list, _next_entity_id must not reset to 1
## or new entities would get colliding ecs_ids with retained entities,
## breaking relationship slot-key uniqueness.
func test_purge_with_keep_preserves_entity_id_counter():
	var keeper = Entity.new()
	var disposable = Entity.new()

	world.add_entity(keeper)
	world.add_entity(disposable)

	var keeper_id = keeper.ecs_id
	assert_int(keeper_id).is_greater(0)

	# Purge everything except keeper
	world.purge(false, [keeper])

	# Add a new entity after purge
	var newcomer = Entity.new()
	world.add_entity(newcomer)

	# New entity must NOT get an ecs_id that matches the keeper's
	assert_int(newcomer.ecs_id).is_not_equal(keeper_id)
	# And the id counter must still be above the kept entity's id
	assert_int(newcomer.ecs_id).is_greater(keeper_id)


## Full purge (no keep list) should still reset _next_entity_id to 1.
func test_full_purge_resets_entity_id_counter():
	var entity = Entity.new()
	world.add_entity(entity)
	assert_int(entity.ecs_id).is_greater(0)

	world.purge(false)

	# After full purge, next entity should get id 1
	var newcomer = Entity.new()
	world.add_entity(newcomer)
	assert_int(newcomer.ecs_id).is_equal(1)


#endregion

#region Regression: without_group + with_relationship must pass structural args


## Queries combining without_group() and with_relationship() must use
## archetype-level structural filtering, not just component-only filtering.
func test_without_group_with_relationship_uses_structural_filtering():
	var entity_in_group = Entity.new()
	var entity_with_rel = Entity.new()
	var entity_both = Entity.new()
	var target = Entity.new()

	world.add_entity(entity_in_group)
	world.add_entity(entity_with_rel)
	world.add_entity(entity_both)
	world.add_entity(target)

	# All have the same component
	entity_in_group.add_component(C_TestA.new())
	entity_with_rel.add_component(C_TestA.new())
	entity_both.add_component(C_TestA.new())

	# Only some have the relationship
	entity_with_rel.add_relationship(Relationship.new(C_TestB.new(), target))
	entity_both.add_relationship(Relationship.new(C_TestB.new(), target))

	# Put some in a group
	entity_in_group.add_to_group("Excluded")
	entity_both.add_to_group("Excluded")

	# Query: has relationship, NOT in excluded group
	var result = (
		world
		.query
		.with_all([C_TestA])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target)],
		)
		.without_group(["Excluded"])
		.execute()
	)

	# Only entity_with_rel qualifies (has rel, not in group)
	assert_int(result.size()).is_equal(1)
	assert_object(result[0]).is_same(entity_with_rel)


## Inverse: with_group + with_relationship also works correctly.
func test_with_group_with_relationship():
	var entity_in_group = Entity.new()
	var entity_with_rel = Entity.new()
	var entity_both = Entity.new()
	var target = Entity.new()

	world.add_entity(entity_in_group)
	world.add_entity(entity_with_rel)
	world.add_entity(entity_both)
	world.add_entity(target)

	entity_in_group.add_component(C_TestA.new())
	entity_with_rel.add_component(C_TestA.new())
	entity_both.add_component(C_TestA.new())

	entity_with_rel.add_relationship(Relationship.new(C_TestB.new(), target))
	entity_both.add_relationship(Relationship.new(C_TestB.new(), target))

	entity_in_group.add_to_group("Players")
	entity_both.add_to_group("Players")

	# Query: has relationship AND in group
	var result = (
		world
		.query
		.with_all([C_TestA])
		.with_relationship(
			[Relationship.new(C_TestB.new(), target)],
		)
		.with_group(["Players"])
		.execute()
	)

	# Only entity_both qualifies (has rel AND in group)
	assert_int(result.size()).is_equal(1)
	assert_object(result[0]).is_same(entity_both)

#endregion
