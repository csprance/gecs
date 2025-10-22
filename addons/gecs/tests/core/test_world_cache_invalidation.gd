extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	if world:
		world.purge(false)

## Test that component addition invalidates cached query results
func test_component_addition_invalidates_cache():
	# Setup entities and initial query
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	world.add_entities([entity1, entity2])
	
	# Add component to entity1 AFTER adding to world
	entity1.add_component(C_TestA.new())
	
	# Execute query and cache result
	var query = world.query.with_all([C_TestA])
	var initial_result = query.execute()
	assert_array(initial_result).has_size(1)
	assert_bool(initial_result.has(entity1)).is_true()
	
	# Add component to entity2 mid-frame
	entity2.add_component(C_TestA.new())
	
	# Execute same query again - should see fresh results
	var updated_result = query.execute()
	assert_array(updated_result).has_size(2)
	assert_bool(updated_result.has(entity1)).is_true()
	assert_bool(updated_result.has(entity2)).is_true()

## Test that component removal invalidates cached query results  
func test_component_removal_invalidates_cache():
	# Setup entities with components
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestA.new())
	world.add_entities([entity1, entity2])
	
	# Execute query and cache result
	var query = world.query.with_all([C_TestA])
	var initial_result = query.execute()
	assert_array(initial_result).has_size(2)
	
	# Remove component from entity1 mid-frame
	entity1.remove_component(C_TestA)
	
	# Execute same query again - should see fresh results
	var updated_result = query.execute()
	assert_array(updated_result).has_size(1)
	assert_bool(updated_result.has(entity2)).is_true()
	assert_bool(updated_result.has(entity1)).is_false()

## Test that multiple component changes in same frame all invalidate cache
func test_multiple_component_changes_invalidate_cache():
	# Setup entities
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	entity1.add_component(C_TestA.new())
	world.add_entities([entity1, entity2, entity3])
	
	# Execute query and cache result
	var query = world.query.with_all([C_TestA])
	var initial_result = query.execute()
	assert_array(initial_result).has_size(1)
	
	# Make multiple changes in same frame
	entity2.add_component(C_TestA.new()) # Add to entity2
	entity3.add_component(C_TestA.new()) # Add to entity3
	entity1.remove_component(C_TestA) # Remove from entity1
	
	# Execute query - should reflect all changes
	var final_result = query.execute()
	assert_array(final_result).has_size(2)
	assert_bool(final_result.has(entity2)).is_true()
	assert_bool(final_result.has(entity3)).is_true()
	assert_bool(final_result.has(entity1)).is_false()

## Test cache invalidation works with complex queries
func test_complex_query_cache_invalidation():
	# Setup entities with multiple components
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	
	entity1.add_component(C_TestA.new())
	entity1.add_component(C_TestB.new())
	
	entity2.add_component(C_TestA.new())
	entity2.add_component(C_TestC.new())
	
	entity3.add_component(C_TestB.new())
	entity3.add_component(C_TestC.new())
	
	world.add_entities([entity1, entity2, entity3])
	
	# Complex query: has TestA AND (TestB OR TestC) but NOT TestD
	var query = world.query.with_all([C_TestA]).with_any([C_TestB, C_TestC]).with_none([C_TestD])
	var initial_result = query.execute()
	assert_array(initial_result).has_size(2) # entity1 and entity2
	
	# Add TestD to entity1 - should remove it from results
	entity1.add_component(C_TestD.new())
	
	var updated_result = query.execute()
	assert_array(updated_result).has_size(1) # only entity2
	assert_bool(updated_result.has(entity2)).is_true()
	assert_bool(updated_result.has(entity1)).is_false()

## Test that cache invalidation signal is properly emitted
func test_cache_invalidation_signal_emission():
	var signal_count = [0] # Use array to avoid closure issues
	
	# Connect to cache invalidation signal
	world.cache_invalidated.connect(func(): 
		signal_count[0] += 1
		print("[TEST] Signal count incremented to: ", signal_count[0])
	)
	
	var entity = Entity.new()
	# Adding entity should emit cache_invalidated once
	print("[TEST] About to add entity, current signal_count: ", signal_count[0])
	world.add_entity(entity)
	print("[TEST] After add entity, signal_count: ", signal_count[0])
	assert_int(signal_count[0]).is_greater_equal(1) # At least one for adding entity
	
	var initial_count = signal_count[0]
	
	# Test if signals are properly connected
	assert_bool(entity.component_added.is_connected(world._on_entity_component_added)).is_true()
	assert_bool(entity.component_removed.is_connected(world._on_entity_component_removed)).is_true()
	
	# Each component operation should emit signal (may be multiple due to archetype creation)
	entity.add_component(C_TestA.new())
	var count_after_add_a = signal_count[0]
	assert_int(count_after_add_a).is_greater(initial_count)

	entity.add_component(C_TestB.new())
	var count_after_add_b = signal_count[0]
	assert_int(count_after_add_b).is_greater(count_after_add_a)

	entity.remove_component(C_TestA)
	var count_after_remove_a = signal_count[0]
	assert_int(count_after_remove_a).is_greater(count_after_add_b)

	entity.remove_component(C_TestB)
	var count_after_remove_b = signal_count[0]
	assert_int(count_after_remove_b).is_greater(count_after_remove_a)

## Test performance: verify cache actually provides speedup when valid
func test_cache_performance_benefit():
	# Create many entities for meaningful performance test
	var entities = []
	for i in range(500):
		var entity = Entity.new()
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		entities.append(entity)
	world.add_entities(entities)
	
	var query = world.query.with_all([C_TestA, C_TestB])
	
	# First execution - uncached
	var time_start = Time.get_ticks_usec()
	var result1 = query.execute()
	var uncached_time = Time.get_ticks_usec() - time_start
	
	# Second execution - should use cache
	time_start = Time.get_ticks_usec()
	var result2 = query.execute()
	var cached_time = Time.get_ticks_usec() - time_start
	
	# Results should be identical
	assert_array(result1).is_equal(result2)
	
	# Cache should be significantly faster
	assert_bool(cached_time < uncached_time).is_true()
	print("Cache performance test - Uncached: %d us, Cached: %d us, Speedup: %.2fx" %
		[uncached_time, cached_time, float(uncached_time) / max(cached_time, 1)])

## Test that world cache clearing works correctly
func test_manual_cache_clearing():
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	world.add_entity(entity)
	
	var query = world.query.with_all([C_TestA])
	var result1 = query.execute() # Cache the result

	# Manually clear cache (now using archetype cache)
	world._query_archetype_cache.clear()

	# Should not affect correctness
	var result2 = query.execute()
	assert_array(result1).is_equal(result2)

## ===============================
## RELATIONSHIP QUERY TESTS
## ===============================
## NOTE: Relationship changes do NOT invalidate cache (performance optimization)
## Instead, queries work because relationship_entity_index is updated in real-time
## These tests verify that queries still return correct results without cache invalidation

## Test that relationship queries work correctly with real-time index updates
func test_relationship_addition_queries_correctly():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var target_entity = Entity.new()
	world.add_entities([entity1, entity2, target_entity])
	
	# Create relationship type
	var rel_component = C_TestA.new()
	
	# Add relationship to entity1
	entity1.add_relationship(Relationship.new(rel_component, target_entity))
	
	# Execute query for entities with this relationship type
	var query = world.query.with_relationship([Relationship.new(C_TestA.new(), ECS.wildcard)])
	var initial_result = query.execute()
	assert_array(initial_result).has_size(1)
	assert_bool(initial_result.has(entity1)).is_true()
	
	# Add same relationship type to entity2 mid-frame
	entity2.add_relationship(Relationship.new(rel_component.duplicate(), target_entity))
	
	# Execute same query again - should see fresh results
	var updated_result = query.execute()
	assert_array(updated_result).has_size(2)
	assert_bool(updated_result.has(entity1)).is_true()
	assert_bool(updated_result.has(entity2)).is_true()

## Test that relationship removal queries work correctly with real-time index
func test_relationship_removal_queries_correctly():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var target_entity = Entity.new()
	world.add_entities([entity1, entity2, target_entity])
	
	# Create relationships
	var rel1 = Relationship.new(C_TestA.new(), target_entity)
	var rel2 = Relationship.new(C_TestA.new(), target_entity)
	entity1.add_relationship(rel1)
	entity2.add_relationship(rel2)
	
	# Execute query and cache result
	var query = world.query.with_relationship([Relationship.new(C_TestA.new(), ECS.wildcard)])
	var initial_result = query.execute()
	assert_array(initial_result).has_size(2)
	
	# Remove relationship from entity1 mid-frame
	entity1.remove_relationship(rel1)
	
	# Execute same query again - should see fresh results
	var updated_result = query.execute()
	assert_array(updated_result).has_size(1)
	assert_bool(updated_result.has(entity2)).is_true()
	assert_bool(updated_result.has(entity1)).is_false()

## Test the exact bug scenario that was fixed
func test_relationship_removal_stale_cache_bug():
	# Simulate the exact scenario from the bug report
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var interactable_entity = Entity.new()
	world.add_entities([entity1, entity2, interactable_entity])
	
	# Create relationships representing "can interact with anything"
	var interact_rel1 = Relationship.new(C_TestA.new(), ECS.wildcard) # Using TestA as interaction relation
	var interact_rel2 = Relationship.new(C_TestA.new(), ECS.wildcard)
	entity1.add_relationship(interact_rel1)
	entity2.add_relationship(interact_rel2)
	
	# First subsystem queries for entities that can interact
	var interaction_query = world.query.with_relationship([Relationship.new(C_TestA.new(), ECS.wildcard)])
	var interaction_entities = interaction_query.execute()
	assert_array(interaction_entities).has_size(2)
	
	# Simulate first entity processing: removes its interaction capability
	assert_bool(interaction_entities.has(entity1)).is_true()
	var first_entity = interaction_entities[0] # Could be entity1 or entity2
	
	# Remove relationship (simulating "used up" interaction)
	if first_entity == entity1:
		first_entity.remove_relationship(interact_rel1)
	else:
		first_entity.remove_relationship(interact_rel2)
	
	# Second subsystem queries again in same frame - should NOT see the removed entity
	var second_query_result = interaction_query.execute()
	assert_array(second_query_result).has_size(1)
	assert_bool(second_query_result.has(first_entity)).is_false()
	
	# Verify the remaining entity still works
	var remaining_entity = second_query_result[0]
	assert_that(remaining_entity).is_not_null()
	# assert_bool(remaining_entity.has_relationship_of_type(C_TestA)).is_true()

## Test multiple relationship changes in same frame query correctly
func test_multiple_relationship_changes_query_correctly():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target_entity = Entity.new()
	world.add_entities([entity1, entity2, entity3, target_entity])
	
	# Setup initial relationships
	var rel1 = Relationship.new(C_TestA.new(), target_entity)
	entity1.add_relationship(rel1)
	
	# Execute query and cache result
	var query = world.query.with_relationship([Relationship.new(C_TestA.new(), ECS.wildcard)])
	var initial_result = query.execute()
	assert_array(initial_result).has_size(1)
	
	# Make multiple relationship changes in same frame
	var rel2 = Relationship.new(C_TestA.new(), target_entity)
	var rel3 = Relationship.new(C_TestA.new(), target_entity)
	entity2.add_relationship(rel2) # Add to entity2
	entity3.add_relationship(rel3) # Add to entity3
	entity1.remove_relationship(rel1) # Remove from entity1
	
	# Execute query - should reflect all changes
	var final_result = query.execute()
	assert_array(final_result).has_size(2)
	assert_bool(final_result.has(entity2)).is_true()
	assert_bool(final_result.has(entity3)).is_true()
	assert_bool(final_result.has(entity1)).is_false()

## Test that relationship changes DO NOT invalidate cache (performance optimization)
func test_relationship_no_cache_invalidation():
	var signal_count = [0]

	# Connect to cache invalidation signal
	world.cache_invalidated.connect(func(): signal_count[0] += 1)

	var entity = Entity.new()
	var target_entity = Entity.new()
	world.add_entities([entity, target_entity])

	var initial_count = signal_count[0]

	# IMPORTANT: Relationship changes should NOT emit cache_invalidated signal
	# This is a performance optimization - relationships use relationship_entity_index
	# which is updated in real-time, so cache invalidation is unnecessary

	var rel1 = Relationship.new(C_TestA.new(), target_entity)
	entity.add_relationship(rel1)
	assert_int(signal_count[0]).is_equal(initial_count) # No invalidation!

	var rel2 = Relationship.new(C_TestB.new(), target_entity)
	entity.add_relationship(rel2)
	assert_int(signal_count[0]).is_equal(initial_count) # No invalidation!

	entity.remove_relationship(rel1)
	assert_int(signal_count[0]).is_equal(initial_count) # No invalidation!

	entity.remove_relationship(rel2)
	assert_int(signal_count[0]).is_equal(initial_count) # No invalidation!

## Test mixed component and relationship cache invalidation
func test_mixed_component_relationship_cache_invalidation():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var target_entity = Entity.new()
	world.add_entities([entity1, entity2, target_entity])
	
	# Setup entity1 with component and relationship
	entity1.add_component(C_TestA.new())
	entity1.add_relationship(Relationship.new(C_TestB.new(), target_entity))
	
	# Complex query: has component AND relationship
	var component_query = world.query.with_all([C_TestA])
	var relationship_query = world.query.with_relationship([Relationship.new(C_TestB.new(), ECS.wildcard)])
	
	# Cache both queries
	var comp_result1 = component_query.execute()
	var rel_result1 = relationship_query.execute()
	assert_array(comp_result1).has_size(1)
	assert_array(rel_result1).has_size(1)
	
	# Add component to entity2 - should invalidate component query only
	entity2.add_component(C_TestA.new())
	
	var comp_result2 = component_query.execute()
	var rel_result2 = relationship_query.execute()
	assert_array(comp_result2).has_size(2) # Component query sees change
	assert_array(rel_result2).has_size(1) # Relationship query unchanged
	
	# Add relationship to entity2 - should invalidate relationship query
	entity2.add_relationship(Relationship.new(C_TestB.new(), target_entity))
	
	var comp_result3 = component_query.execute()
	var rel_result3 = relationship_query.execute()
	assert_array(comp_result3).has_size(2) # Component query unchanged
	assert_array(rel_result3).has_size(2) # Relationship query sees change
