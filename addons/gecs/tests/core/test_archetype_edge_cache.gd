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
	var collision_query = QueryBuilder.new(world).with_all([C_TestA, C_TestB])
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
