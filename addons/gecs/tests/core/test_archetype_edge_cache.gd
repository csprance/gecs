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
