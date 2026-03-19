class_name TestStructuralTransitions
extends GdUnitTestSuite
## Test suite for structural relationship transitions.
## Verifies that relationship add/remove triggers archetype moves,
## batch optimization produces single transitions, cache invalidation fires,
## and REMOVE policy cleans up freed-target relationships.
##
## Covers TRAN-01 through TRAN-05.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## TRAN-01: add_relationship() moves entity to a new archetype that includes the rel:// pair slot key.
func test_add_relationship_moves_archetype():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	entity.add_component(C_TestA.new())

	var old_archetype = world.entity_to_archetype[entity]

	entity.add_relationship(Relationship.new(C_TestA.new(), target))

	var new_archetype = world.entity_to_archetype[entity]
	assert_object(new_archetype).is_not_same(old_archetype)
	# New archetype should have a rel:// slot key
	assert_bool(new_archetype.relationship_types.size() > 0).is_true()
	var has_rel_key = false
	for rt in new_archetype.relationship_types:
		if rt.begins_with("rel://"):
			has_rel_key = true
			break
	assert_bool(has_rel_key).is_true()


## TRAN-02: remove_relationship() moves entity back to archetype without the rel:// pair slot key.
func test_remove_relationship_moves_archetype():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	entity.add_component(C_TestA.new())

	entity.add_relationship(Relationship.new(C_TestA.new(), target))
	var archetype_with_rel = world.entity_to_archetype[entity]
	assert_bool(archetype_with_rel.relationship_types.size() > 0).is_true()

	entity.remove_relationship(Relationship.new(C_TestA.new(), target))
	var archetype_without_rel = world.entity_to_archetype[entity]

	assert_object(archetype_without_rel).is_not_same(archetype_with_rel)
	assert_bool(archetype_without_rel.relationship_types.is_empty()).is_true()


## TRAN-03: add_relationships([r1, r2, r3]) performs exactly one archetype transition (not 3).
func test_add_relationships_batch_single_transition():
	var entity = Entity.new()
	var t1 = Entity.new()
	var t2 = Entity.new()
	var t3 = Entity.new()

	world.add_entity(entity)
	world.add_entity(t1)
	world.add_entity(t2)
	world.add_entity(t3)

	entity.add_component(C_TestA.new())
	var _old_archetype = world.entity_to_archetype[entity]

	world.reset_cache_stats()

	entity.add_relationships([
		Relationship.new(C_TestA.new(), t1),
		Relationship.new(C_TestB.new(), t2),
		Relationship.new(C_TestA.new(), t3),
	])

	var final_archetype = world.entity_to_archetype[entity]
	# All 3 relationship slot keys should be present
	assert_int(final_archetype.relationship_types.size()).is_equal(3)

	# Cache invalidation should be minimal — not 3 separate invalidations
	var stats = world.get_cache_stats()
	assert_int(stats.invalidation_count).is_less_equal(2)


## TRAN-04a: Cache invalidation fires on relationship add.
func test_cache_invalidation_on_relationship_add():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	entity.add_component(C_TestA.new())

	world.reset_cache_stats()
	entity.add_relationship(Relationship.new(C_TestA.new(), target))

	var stats = world.get_cache_stats()
	assert_int(stats.invalidation_count).is_greater(0)


## TRAN-04b: Cache invalidation fires on relationship remove.
func test_cache_invalidation_on_relationship_remove():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	entity.add_component(C_TestA.new())
	entity.add_relationship(Relationship.new(C_TestA.new(), target))

	world.reset_cache_stats()
	entity.remove_relationship(Relationship.new(C_TestA.new(), target))

	var stats = world.get_cache_stats()
	assert_int(stats.invalidation_count).is_greater(0)


## TRAN-05a: When target entity is removed, source entity's relationship is cleaned up.
func test_freed_target_cleanup_single_source():
	var source = Entity.new()
	var target = Entity.new()

	world.add_entity(source)
	world.add_entity(target)

	source.add_component(C_TestA.new())
	source.add_relationship(Relationship.new(C_TestA.new(), target))

	assert_int(source.relationships.size()).is_equal(1)

	world.remove_entity(target)

	assert_int(source.relationships.size()).is_equal(0)
	assert_bool(is_instance_valid(source)).is_true()
	assert_bool(world.entities.has(source)).is_true()


## TRAN-05b: When target is removed, ALL source entities' relationships to it are cleaned up.
func test_freed_target_cleanup_multiple_sources():
	var source1 = Entity.new()
	var source2 = Entity.new()
	var source3 = Entity.new()
	var target = Entity.new()

	world.add_entity(source1)
	world.add_entity(source2)
	world.add_entity(source3)
	world.add_entity(target)

	source1.add_component(C_TestA.new())
	source2.add_component(C_TestA.new())
	source3.add_component(C_TestA.new())

	source1.add_relationship(Relationship.new(C_TestA.new(), target))
	source2.add_relationship(Relationship.new(C_TestA.new(), target))
	source3.add_relationship(Relationship.new(C_TestB.new(), target))

	world.remove_entity(target)

	assert_int(source1.relationships.size()).is_equal(0)
	assert_int(source2.relationships.size()).is_equal(0)
	assert_int(source3.relationships.size()).is_equal(0)


## TRAN-05c: When source entity is already freed before target cleanup, cleanup doesn't crash.
func test_freed_target_cleanup_skips_invalid_source():
	var source1 = Entity.new()
	var source2 = Entity.new()
	var target = Entity.new()

	world.add_entity(source1)
	world.add_entity(source2)
	world.add_entity(target)

	source1.add_component(C_TestA.new())
	source2.add_component(C_TestA.new())

	source1.add_relationship(Relationship.new(C_TestA.new(), target))
	source2.add_relationship(Relationship.new(C_TestA.new(), target))

	# Remove source1 first — it's freed and invalid
	world.remove_entity(source1)

	# Now remove target — cleanup should skip source1 (invalid) and clean source2
	world.remove_entity(target)

	assert_int(source2.relationships.size()).is_equal(0)


## Regression: add then remove returns entity to original archetype (same signature).
func test_add_remove_relationship_returns_to_original_archetype():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	entity.add_component(C_TestA.new())

	var original_sig = world._calculate_entity_signature(entity)

	entity.add_relationship(Relationship.new(C_TestA.new(), target))
	entity.remove_relationship(Relationship.new(C_TestA.new(), target))

	var restored_sig = world._calculate_entity_signature(entity)
	assert_int(restored_sig).is_equal(original_sig)
