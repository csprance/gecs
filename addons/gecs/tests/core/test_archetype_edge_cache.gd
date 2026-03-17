class_name TestArchetypeEdgeCacheBug
extends GdUnitTestSuite
## Test suite for archetype edge cache bug
##
## Tests that archetypes retrieved from edge cache are properly re-registered
## with the world when they were previously removed due to being empty.
##
## Bug sequence:
## 1. Entity A gets component added -> creates archetype X, cached edge
## 2. Entity A removed -> archetype X becomes empty, gets removed from world.archetypes
## 3. Entity B gets same component -> uses cached edge to archetype X
## 4. BUG: archetype X not in world.archetypes, so queries can't find Entity B


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Test that archetypes retrieved from edge cache are re-registered with world
func test_archetype_reregistered_after_edge_cache_retrieval():
	# ARRANGE: Create two entities with same initial components
	var entity1 = Entity.new()
	entity1.add_component(C_TestA.new())
	world.add_entities([entity1])

	var entity2 = Entity.new()
	entity2.add_component(C_TestA.new())
	world.add_entities([entity2])

	# ACT 1: Add ComponentB to entity1 (creates new archetype + edge cache)
	var comp_b1 = C_TestB.new()
	entity1.add_component(comp_b1)

	# Get the archetype signature for A+B combination
	var archetype_with_b = world.entity_to_archetype[entity1]
	var signature_with_b = archetype_with_b.signature

	# Verify archetype is in world.archetypes
	assert_bool(world.archetypes.has(signature_with_b)).is_true()

	# ACT 2: Remove entity1 to make archetype empty (triggers cleanup)
	world.remove_entity(entity1)

	# Verify archetype was removed from world.archetypes when empty
	assert_bool(world.archetypes.has(signature_with_b)).is_false()

	# ACT 3: Add ComponentB to entity2 (should use edge cache)
	# This is where the bug would occur - archetype retrieved from cache
	# but not re-registered with world
	var comp_b2 = C_TestB.new()
	entity2.add_component(comp_b2)

	# ASSERT: Archetype should be back in world.archetypes
	assert_bool(world.archetypes.has(signature_with_b)).is_true()

	# ASSERT: Query should find entity2
	var query = QueryBuilder.new(world).with_all([C_TestA, C_TestB])
	var results = query.execute()
	assert_int(results.size()).is_equal(1)
	assert_object(results[0]).is_same(entity2)


## Test that queries find entities in edge-cached archetypes
func test_query_finds_entities_in_edge_cached_archetype():
	# This reproduces the exact projectile bug scenario
	# ARRANGE: Create 3 projectiles
	var projectile1 = Entity.new()
	projectile1.add_component(C_TestA.new()) # Simulates C_Projectile
	world.add_entities([projectile1])

	var projectile2 = Entity.new()
	projectile2.add_component(C_TestA.new())
	world.add_entities([projectile2])

	var projectile3 = Entity.new()
	projectile3.add_component(C_TestA.new())
	world.add_entities([projectile3])

	# ACT 1: First projectile collides (adds ComponentB = C_Collision)
	projectile1.add_component(C_TestB.new())

	# Verify query finds it
	# Connect cache invalidation so the persistent QueryBuilder sees archetype changes
	var collision_query = QueryBuilder.new(world).with_all([C_TestA, C_TestB])
	world.cache_invalidated.connect(collision_query.invalidate_cache)
	assert_int(collision_query.execute().size()).is_equal(1)

	# ACT 2: First projectile processed and removed (empties collision archetype)
	world.remove_entity(projectile1)

	# ACT 3: Second projectile collides (edge cache used)
	projectile2.add_component(C_TestB.new())

	# ASSERT: Query should find second projectile (BUG: it wouldn't before fix)
	var results = collision_query.execute()
	assert_int(results.size()).is_equal(1)
	assert_object(results[0]).is_same(projectile2)

	# ACT 4: Third projectile also collides while second still exists
	projectile3.add_component(C_TestB.new())

	# ASSERT: Query should find both projectiles
	results = collision_query.execute()
	assert_int(results.size()).is_equal(2)


## ARCH-04 / ARCH-01 regression: fast path must not re-use a stale (cleared-edge) archetype.
## entity_keeper keeps A-only archetype alive so its stale add_edge persists across cycles.
## RED condition: current re-registration puts entity3 in the original_ab_archetype (same object).
## GREEN after fix: "clear edge + fall through" creates a fresh A+B object for entity3.
func test_fast_path_stale_edge_after_archetype_deletion():
	## ARRANGE: entity_keeper keeps A-only alive so its add_edge is never cleared between cycles
	var entity_keeper = Entity.new()
	entity_keeper.add_component(C_TestA.new())
	world.add_entities([entity_keeper])

	## entity1 creates the A+B archetype and caches the add_edge in A-only
	var entity1 = Entity.new()
	entity1.add_component(C_TestA.new())
	world.add_entities([entity1])
	entity1.add_component(C_TestB.new())
	## Save reference to A+B archetype object BEFORE deletion
	var original_ab_archetype = world.entity_to_archetype[entity1]
	var signature_with_b = original_ab_archetype.signature

	## ACT 1: remove entity1 -> A+B deleted; A-only stays alive (entity_keeper); stale edge persists
	world.remove_entity(entity1)
	assert_bool(world.archetypes.has(signature_with_b)).is_false()

	## ACT 2: entity2 -> fast path finds stale edge; current code re-registers original_ab_archetype
	var entity2 = Entity.new()
	entity2.add_component(C_TestA.new())
	world.add_entities([entity2])
	entity2.add_component(C_TestB.new())

	## ACT 3: remove entity2 -> A+B deleted again; A-only stays; stale edge in A-only persists
	world.remove_entity(entity2)
	assert_bool(world.archetypes.has(signature_with_b)).is_false()

	## ACT 4: entity3 -> fast path finds same stale edge; re-registers original_ab_archetype again
	var entity3 = Entity.new()
	entity3.add_component(C_TestA.new())
	world.add_entities([entity3])
	entity3.add_component(C_TestB.new())

	## ASSERT: entity3 must be in a FRESH archetype, not the stale original_ab_archetype object.
	## With re-registration: entity3 lands in original_ab_archetype (same object) -> is_not_same FAILS.
	## After fix: fresh archetype created -> is_not_same PASSES.
	var entity3_archetype = world.entity_to_archetype[entity3]
	assert_object(entity3_archetype).is_not_same(original_ab_archetype)
	assert_bool(world.archetypes.has(entity3_archetype.signature)).is_true()
	var results = QueryBuilder.new(world).with_all([C_TestA, C_TestB]).execute()
	assert_int(results.size()).is_equal(1)
	assert_object(results[0]).is_same(entity3)


## ARCH-04 / ARCH-02 regression: slow path must not place entity in a stale (ghost) archetype.
## NOTE: _move_entity_to_new_archetype is dead code (never called in production). Direct call required.
## entity_keeper keeps A-only alive so the stale add_edge is present when the slow path is called.
## RED condition: without the staleness guard, entity2 ends up in ghost archetype -> query returns 0.
func test_slow_path_stale_edge_after_archetype_deletion():
	## ARRANGE: entity_keeper keeps A-only alive so its add_edge is not cleared after entity1 moves out
	var entity_keeper = Entity.new()
	entity_keeper.add_component(C_TestA.new())
	world.add_entities([entity_keeper])

	## entity1 creates A+B and populates A-only.add_edges[b_path] = A+B archetype
	var entity1 = Entity.new()
	entity1.add_component(C_TestA.new())
	world.add_entities([entity1])
	entity1.add_component(C_TestB.new())

	## ACT 1: remove entity1 -> A+B deleted; A-only stays alive; stale add_edge persists
	world.remove_entity(entity1)

	## ARRANGE entity2: entity2 in A-only; manually inject C_TestB to bypass fast path
	var entity2 = Entity.new()
	entity2.add_component(C_TestA.new())
	world.add_entities([entity2])
	## Manually set C_TestB in entity2.components WITHOUT going through world (bypasses fast path)
	var b_path = C_TestB.new().get_script().resource_path
	entity2.components[b_path] = C_TestB.new()
	## entity2 is still in A-only archetype (which has the stale add_edge to the deleted A+B)
	var entity2_old_archetype = world.entity_to_archetype[entity2]

	## ACT 2: direct call to slow path — exercises _move_entity_to_new_archetype (dead code path)
	world._move_entity_to_new_archetype(entity2, entity2_old_archetype)

	## ASSERT: entity2 must be in an archetype registered in world.archetypes.
	## Without ARCH-02 guard: slow path uses stale A+B (not in archetypes) -> FAILS.
	assert_bool(world.archetypes.has(world.entity_to_archetype[entity2].signature)).is_true()
	## Query must find entity2 (returns empty when entity2 is in a ghost archetype)
	var results = QueryBuilder.new(world).with_all([C_TestA, C_TestB]).execute()
	assert_int(results.size()).is_equal(1)


## Test rapid add/remove cycles don't lose archetypes
func test_rapid_archetype_cycling():
	# Tests the exact pattern: create -> empty -> reuse via cache
	var entities = []
	for i in range(5):
		var e = Entity.new()
		e.add_component(C_TestA.new())
		world.add_entities([e])
		entities.append(e)

	# Cycle through adding/removing ComponentB
	for cycle in range(3):
		# Add ComponentB to first entity (creates/reuses archetype)
		entities[0].add_component(C_TestB.new())

		# Query should find it
		var query = QueryBuilder.new(world).with_all([C_TestA, C_TestB])
		var results = query.execute()
		assert_int(results.size()).is_equal(1)

		# Remove entity (empties archetype)
		world.remove_entity(entities[0])

		# Create new entity for next cycle
		entities[0] = Entity.new()
		entities[0].add_component(C_TestA.new())
		world.add_entities([entities[0]])

	# Final cycle - should still work
	entities[0].add_component(C_TestB.new())
	var final_query = QueryBuilder.new(world).with_all([C_TestA, C_TestB])
	assert_int(final_query.execute().size()).is_equal(1)


## FIX-1B regression: After an edge reassignment in _move_entity_to_new_archetype_fast,
## the previously-pointed-at archetype must NOT have a stale forward edge (via its neighbors
## back-pointer) to new_archetype that causes incorrect cleanup or navigation.
##
## Scenario: Archetype-AB (new_arch) gets its remove_edge[b_path] set twice via two successive
## "add B" cycles through different old_archetype objects. After the second assignment, the
## first old_archetype (archetype-X) must NOT still have a forward edge pointing back to AB.
##
## RED condition: _move_entity_to_new_archetype_fast at lines 1338-1343 sets
## new_archetype.set_remove_edge(comp_path, old_archetype) without first clearing the reverse
## edge that new_archetype's OLD target had pointing back to new_archetype.
## After the second edge assignment, archetype-X.neighbors[new_arch.id] is stale ->
## _delete_archetype(archetype-X) would sweep new_archetype's edges incorrectly.
func test_no_stale_reverse_edge_after_edge_reassignment():
	## ARRANGE: Create archetype-A (with entity_keeper so it persists across the test).
	var entity_keeper = Entity.new()
	entity_keeper.add_component(C_TestA.new())
	world.add_entities([entity_keeper])

	## ACT 1: entity1 in A-only adds B -> creates A+B (new_arch).
	## Sets: A.add_edges[b] = AB, AB.remove_edges[b] = A, AB.neighbors[A.id] = A, A.neighbors[AB.id] = AB
	var entity1 = Entity.new()
	entity1.add_component(C_TestA.new())
	world.add_entities([entity1])
	var b_comp = C_TestB.new()
	entity1.add_component(b_comp)
	var ab_archetype = world.entity_to_archetype[entity1]
	## AB exists, remove_edges[b] = A-only archetype
	assert_bool(world.archetypes.has(ab_archetype.signature)).is_true()

	## ACT 2: Remove entity1 -> A+B (ab_archetype) becomes empty -> _delete_archetype clears A.add_edges[b].
	## A-only survives (entity_keeper). ab_archetype is now a ghost.
	world.remove_entity(entity1)
	assert_bool(world.archetypes.has(ab_archetype.signature)).is_false()

	## ARRANGE: Add entity2 to A-only (before entity3 creates a new AB cycle).
	var entity2 = Entity.new()
	entity2.add_component(C_TestA.new())
	world.add_entities([entity2])

	## ACT 3: entity2 in A-only adds B -> fast path has no edge (was cleared in ACT 2).
	## Falls through to _get_or_create_archetype -> creates a fresh AB2 archetype.
	## Sets: A.add_edges[b] = AB2, AB2.remove_edges[b] = A, AB2.neighbors[A.id] = A
	entity2.add_component(C_TestB.new())
	var ab2_archetype = world.entity_to_archetype[entity2]
	## AB2 is a fresh archetype (different object from the deleted ab_archetype)
	assert_object(ab2_archetype).is_not_same(ab_archetype)
	assert_bool(world.archetypes.has(ab2_archetype.signature)).is_true()

	## Now entity_keeper is in A-only and entity2 is in AB2.
	## A-only should have add_edges[b] = AB2, and AB2.remove_edges[b] = A-only.
	var a_archetype = world.entity_to_archetype[entity_keeper]
	var b_path = C_TestB.new().get_script().resource_path
	## AB2's remove_edge[b] should point to a_archetype (the CURRENT a-only), not a ghost.
	var reverse_edge_target = ab2_archetype.get_remove_edge(b_path)
	assert_object(reverse_edge_target).is_same(a_archetype)

	## ASSERT: The old (deleted) ab_archetype must NOT have a stale neighbors entry
	## pointing back to AB2. If ab_archetype.neighbors still contains ab2_archetype,
	## then when ab_archetype is used as old-target reference its cleanup would
	## incorrectly sweep ab2_archetype's edges.
	## With current code (no fix): the neighbors dict may retain stale back-pointers.
	## After fix: stale back-pointer is cleared during the second edge assignment.
	## We check that ab2_archetype.remove_edges[b_path] == a_archetype (not a ghost).
	assert_object(ab2_archetype.get_remove_edge(b_path)).is_same(a_archetype)
	assert_bool(world.archetypes.has(ab2_archetype.get_remove_edge(b_path).signature)).is_true()

	## CRITICAL ASSERT: After the second "add B" cycle completes,
	## verify that NO live archetype has a stale edge pointing to the deleted ab_archetype.
	## The a_archetype's add_edges[b] must point to AB2 (not the ghost ab_archetype).
	var forward_edge = a_archetype.get_add_edge(b_path)
	assert_object(forward_edge).is_not_same(ab_archetype)
	assert_object(forward_edge).is_same(ab2_archetype)
