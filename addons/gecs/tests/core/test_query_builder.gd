extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


func test_query_entities_with_all_components():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var test_c = C_TestC.new()

	# Entity1 has TestA and TestB
	entity1.add_component(test_a)
	entity1.add_component(test_b)
	# Entity2 has TestA only
	entity2.add_component(test_a.duplicate())
	# Entity3 has all three components
	entity3.add_component(test_a.duplicate())
	entity3.add_component(test_b.duplicate())
	entity3.add_component(test_c.duplicate())

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Query entities with TestA
	var result = QueryBuilder.new(world).with_all([C_TestA]).execute()
	assert_array(result).has_size(3)

	result = QueryBuilder.new(world).with_all([C_TestA, C_TestB]).execute()
	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity3)).is_true()
	assert_bool(result.has(entity2)).is_false()


func test_query_entities_with_any_components():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var test_c = C_TestC.new()

	# Entity1 has TestA
	entity1.add_component(test_a)
	# Entity2 has TestB
	entity2.add_component(test_b)
	# Entity3 has TestC
	entity3.add_component(test_c)

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Query entities with any of TestA or TestB
	var result = QueryBuilder.new(world).with_any([C_TestA, C_TestB]).execute()
	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_false()


func test_query_entities_excluding_components():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()

	# Entity1 has TestA
	entity1.add_component(test_a)
	# Entity2 has TestA and TestB
	entity2.add_component(test_a.duplicate())
	entity2.add_component(test_b)
	# Entity3 has no components

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Query entities with TestA but excluding those with TestB
	var result = QueryBuilder.new(world).with_all([C_TestA]).with_none([C_TestB]).execute()
	assert_array(result).has_size(1)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_false()
	assert_bool(result.has(entity3)).is_false()


func test_query_entities_with_all_and_any_components():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var entity4 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var test_c = C_TestC.new()
	var test_d = C_TestD.new()

	# Entity1 has TestA and TestB
	entity1.add_component(test_a)
	entity1.add_component(test_b)
	# Entity2 has TestA, TestB, and TestC
	entity2.add_component(test_a.duplicate())
	entity2.add_component(test_b.duplicate())
	entity2.add_component(test_c)
	# Entity3 has TestA, TestB, and TestD
	entity3.add_component(test_a.duplicate())
	entity3.add_component(test_b.duplicate())
	entity3.add_component(test_d)
	# Entity4 has TestA only
	entity4.add_component(test_a.duplicate())

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(entity4)

	# Query entities with TestA and TestB, and any of TestC or TestD
	var result = (
		QueryBuilder.new(world).with_all([C_TestA, C_TestB]).with_any([C_TestC, C_TestD]).execute()
	)
	assert_array(result).has_size(2)
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_true()
	assert_bool(result.has(entity1)).is_false()
	assert_bool(result.has(entity4)).is_false()


func test_query_entities_with_any_and_exclude_components():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var entity4 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var test_c = C_TestC.new()

	# Entity1 has TestA
	entity1.add_component(test_a)
	# Entity2 has TestB
	entity2.add_component(test_b)
	# Entity3 has TestC
	entity3.add_component(test_c)
	# Entity4 has TestA and TestB
	entity4.add_component(test_a.duplicate())
	entity4.add_component(test_b.duplicate())

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(entity4)

	# Query entities with any of TestA or TestB, excluding TestC
	var result = QueryBuilder.new(world).with_any([C_TestA, C_TestB]).with_none([C_TestC]).execute()
	assert_array(result).has_size(3)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity4)).is_true()
	assert_bool(result.has(entity3)).is_false()


func test_query_entities_with_all_any_and_exclude_components():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var entity4 = Entity.new()
	var entity5 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var test_c = C_TestC.new()
	var test_d = C_TestD.new()
	var test_e = C_TestE.new()

	# Entity1 has TestA, TestB, TestD
	entity1.add_component(test_a)
	entity1.add_component(test_b)
	entity1.add_component(test_d)
	# Entity2 has TestA, TestB, TestC
	entity2.add_component(test_a.duplicate())
	entity2.add_component(test_b.duplicate())
	entity2.add_component(test_c)
	# Entity3 has TestA, TestB, TestE
	entity3.add_component(test_a.duplicate())
	entity3.add_component(test_b.duplicate())
	entity3.add_component(test_e)
	# Entity4 has TestB, TestC
	entity4.add_component(test_b.duplicate())
	entity4.add_component(test_c.duplicate())
	# Entity5 has TestA, TestB, TestC, TestD
	entity5.add_component(test_a.duplicate())
	entity5.add_component(test_b.duplicate())
	entity5.add_component(test_c.duplicate())
	entity5.add_component(test_d.duplicate())

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(entity4)
	world.add_entity(entity5)

	# Query entities with TestA and TestB, any of TestC or TestE, excluding TestD
	var result = (
		QueryBuilder
		.new(world)
		.with_all([C_TestA, C_TestB])
		.with_any([C_TestC, C_TestE])
		.with_none([C_TestD])
		.execute()
	)

	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_false()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_true()
	assert_bool(result.has(entity4)).is_false()
	assert_bool(result.has(entity5)).is_false()


func test_query_entities_with_nothing():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	world.add_entity(entity1)
	world.add_entity(entity2)

	# Query with no components specified should return all entities
	var result = QueryBuilder.new(world).execute()
	assert_array(result).has_size(2)


func test_query_entities_excluding_only():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	var test_c = C_TestC.new()

	# Entity1 has TestC
	entity1.add_component(test_c)
	# Entity2 and Entity3 have no components

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Query excluding entities with TestC
	var result = QueryBuilder.new(world).with_none([C_TestC]).execute()
	assert_array(result).has_size(2)
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_true()
	assert_bool(result.has(entity1)).is_false()


func test_query_with_no_matching_entities():
	var entity1 = Entity.new()
	var entity2 = Entity.new()

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()

	# Entity1 has TestA
	entity1.add_component(test_a)
	# Entity2 has TestB
	entity2.add_component(test_b)

	world.add_entity(entity1)
	world.add_entity(entity2)

	# Query entities with both TestA and TestB (no entity has both)
	var result = QueryBuilder.new(world).with_all([C_TestA, C_TestB]).execute()
	assert_array(result).has_size(0)

	# Edge case: Entity with duplicate components
	var entity = Entity.new()
	var test_a1 = C_TestA.new()
	var test_a2 = C_TestA.new()

	# Add two TestA components to the same entity
	entity.add_component(test_a1)
	entity.add_component(test_a2)

	world.add_entity(entity)

	# Query entities with TestA
	result = QueryBuilder.new(world).with_all([C_TestA]).execute()
	assert_array(result).has_size(2)
	assert_bool(result.has(entity)).is_true()
	assert_bool(result.has(entity1)).is_true()


func test_query_entities_with_multiple_excludes():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var entity4 = Entity.new()

	var test_c = C_TestC.new()
	var test_a = C_TestA.new()
	var test_d = C_TestD.new()

	# Entity1 has TestC
	entity1.add_component(test_c)
	# Entity2 has TestA and TestD
	entity2.add_component(test_a)
	entity2.add_component(test_d)
	# Entity3 has TestD only
	entity3.add_component(test_d.duplicate())
	# Entity4 has no components

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(entity4)

	# Query excluding entities with TestC or TestD
	var result = QueryBuilder.new(world).with_none([C_TestC, C_TestD]).execute()
	assert_array(result).has_size(1)
	assert_bool(result.has(entity4)).is_true()
	assert_bool(result.has(entity1)).is_false()
	assert_bool(result.has(entity2)).is_false()
	assert_bool(result.has(entity3)).is_false()


func test_query_matches():
	var entitya = auto_free(Entity.new())
	var entityb = auto_free(Entity.new())
	var entityc = auto_free(Entity.new())
	var entityd = auto_free(Entity.new())
	var entitye = auto_free(Entity.new())

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var test_c = C_TestC.new()
	var test_d = C_TestD.new()

	# Entitya has TestA
	entitya.add_component(test_a)
	# Entityb has TestA and TestD
	entityb.add_component(test_a.duplicate())
	entityb.add_component(test_d)
	# Entityc has TestD only
	entityc.add_component(test_d.duplicate())
	# Entityd has no components
	# Entitye has TestA, TestB, TestC
	entitye.add_component(test_a.duplicate())
	entitye.add_component(test_b)
	entitye.add_component(test_c)

	var q = QueryBuilder.new(world)

	# test with no query (should match all entities)
	assert_array(q.matches([entitya, entityb, entityc, entityd, entitye])).has_size(5)
	q.clear()
	# Test with_all
	(
		assert_array(q.with_all([C_TestA]).matches([entitya, entityb, entityc, entityd, entitye]))
		.has_size(3)
	)
	(
		assert_bool(
			q.with_all([C_TestA]).matches([entitya, entityb, entityc, entityd, entitye]).has(
				entitya
			)
		)
		.is_true()
	)
	(
		assert_bool(
			q.with_all([C_TestA]).matches([entitya, entityb, entityc, entityd, entitye]).has(
				entityb
			)
		)
		.is_true()
	)
	(
		assert_bool(
			q.with_all([C_TestA]).matches([entitya, entityb, entityc, entityd, entitye]).has(
				entitye
			)
		)
		.is_true()
	)
	q.clear()

	# Test multiple with_all
	(
		assert_array(
			q.with_all([C_TestA, C_TestD]).matches([entitya, entityb, entityc, entityd, entitye])
		)
		.has_size(1)
	)
	(
		assert_bool(
			(
				q
				.with_all([C_TestA, C_TestD])
				.matches([entitya, entityb, entityc, entityd, entitye])
				.has(entityb)
			)
		)
		.is_true()
	)
	q.clear()

	# Test with_none
	assert_array(q.with_none([C_TestB]).matches([entitya, entityb, entityc, entityd])).has_size(4)
	assert_array(q.with_none([C_TestB]).matches([entitya, entityb])).has_size(2)
	q.clear()

	# Test with_any
	(
		assert_array(
			q.with_any([C_TestA, C_TestD]).matches([entitya, entityb, entityc, entityd, entitye])
		)
		.has_size(4)
	)
	(
		assert_bool(
			(
				q
				.with_any([C_TestA, C_TestD])
				.matches([entitya, entityb, entityc, entityd, entitye])
				.has(entityc)
			)
		)
		.is_true()
	)
	(
		assert_bool(
			(
				q
				.with_any([C_TestA, C_TestD])
				.matches([entitya, entityb, entityc, entityd, entitye])
				.has(entityd)
			)
		)
		.is_false()
	)
	q.clear()

	# Test combination of with_all and with_any
	(
		assert_array(
			q.with_all([C_TestA]).with_any([C_TestB, C_TestC]).matches(
				[entitya, entityb, entityc, entityd, entitye]
			)
		)
		.has_size(1)
	)
	(
		assert_bool(
			(
				q
				.with_all([C_TestA])
				.with_any([C_TestB, C_TestC])
				.matches([entitya, entityb, entityc, entityd, entitye])
				.has(entitye)
			)
		)
		.is_true()
	)
	q.clear()

	# Test combination of with_all and with_none
	(
		assert_array(
			q.with_all([C_TestA]).with_none([C_TestD]).matches(
				[entitya, entityb, entityc, entityd, entitye]
			)
		)
		.has_size(2)
	)
	(
		assert_bool(
			(
				q
				.with_all([C_TestA])
				.with_none([C_TestD])
				.matches([entitya, entityb, entityc, entityd, entitye])
				.has(entitya)
			)
		)
		.is_true()
	)
	(
		assert_bool(
			(
				q
				.with_all([C_TestA])
				.with_none([C_TestD])
				.matches([entitya, entityb, entityc, entityd, entitye])
				.has(entitye)
			)
		)
		.is_true()
	)
	q.clear()

	# Test combination of all three query types
	(
		assert_array(
			q.with_all([C_TestA]).with_any([C_TestB, C_TestC]).with_none([C_TestD]).matches(
				[entitya, entityb, entityc, entityd, entitye]
			)
		)
		.has_size(1)
	)
	(
		assert_bool(
			(
				q
				.with_all([C_TestA])
				.with_any([C_TestB, C_TestC])
				.with_none([C_TestD])
				.matches([entitya, entityb, entityc, entityd, entitye])
				.has(entitye)
			)
		)
		.is_true()
	)
	q.clear()


func test_query_matches_with_relationships():
	var entitya = auto_free(Entity.new())
	var entityb = auto_free(Entity.new())
	var entityc = auto_free(Entity.new())

	var test_a = C_TestA.new()
	var test_b = C_TestB.new()
	var rel_a = Relationship.new(test_a, entityb)
	var rel_b = Relationship.new(test_b, entityc)

	# EntityA has relationship with EntityB using TestA
	entitya.add_relationship(rel_a)
	# EntityB has relationship with EntityC using TestB
	entityb.add_relationship(rel_b)

	var q = QueryBuilder.new(world)

	# Test with_relationship
	var result = q.with_relationship([Relationship.new(C_TestA.new(), ECS.wildcard)]).matches(
		[entitya, entityb, entityc]
	)
	assert_array(result).has_size(1)
	assert_bool(result.has(entitya)).is_true()
	q.clear()

	# Test without_relationship
	result = q.without_relationship([Relationship.new(C_TestA.new(), Entity)]).matches(
		[entitya, entityb, entityc]
	)
	assert_array(result).has_size(2)
	assert_bool(result.has(entityb)).is_true()
	assert_bool(result.has(entityc)).is_true()
	q.clear()

	# Test combination of relationships and components
	entitya.add_component(test_a.duplicate())
	result = q.with_all([C_TestA]).with_relationship([Relationship.new(C_TestA.new())]).matches(
		[entitya, entityb, entityc]
	)
	assert_array(result).has_size(1)
	assert_bool(result.has(entitya)).is_true()
	q.clear()


func test_query_with_component_query():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var entity4 = Entity.new()

	var test_a = C_TestA.new()
	var test_d = C_TestD.new()

	# Entity1 has TestC value 25 and TestA
	entity1.add_component(C_TestC.new(25))
	entity1.add_component(test_a)
	# Entity2 has TestA and TestC but value 10
	entity2.add_component(test_a)
	entity2.add_component(C_TestC.new(10))
	# Entity3 has TestD only
	entity3.add_component(test_d.duplicate())
	# Entity4 has no components

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(entity4)

	# Query excluding entities with TestC or TestD
	var result = (
		QueryBuilder.new(world).with_all([ {C_TestC: {"value": {"_eq": 25}}}, C_TestA]).execute()
	)
	assert_array(result).has_size(1)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_false()
	assert_bool(result.has(entity3)).is_false()
	assert_bool(result.has(entity4)).is_false()


func test_query_with_component_queries():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var entity4 = Entity.new()

	# Entity1: TestC(value=25), TestD(points=100)
	entity1.add_component(C_TestC.new(25))
	entity1.add_component(C_TestD.new(100))

	# Entity2: TestC(value=10), TestD(points=50)
	entity2.add_component(C_TestC.new(10))
	entity2.add_component(C_TestD.new(50))

	# Entity3: TestC(value=25), TestD(points=25)
	entity3.add_component(C_TestC.new(25))
	entity3.add_component(C_TestD.new(25))

	# Entity4: TestC(value=30)
	entity4.add_component(C_TestC.new(30))

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(entity4)

	# Test with_all with multiple component queries
	var result = (
		QueryBuilder
		.new(world)
		.with_all([ {C_TestC: {"value": {"_eq": 25}}}, {C_TestD: {"points": {"_gt": 50}}}])
		.execute()
	)
	assert_array(result).has_size(1)
	assert_bool(result.has(entity1)).is_true()

	# Test with_any with component queries
	result = (
		QueryBuilder
		.new(world)
		.with_any([ {C_TestC: {"value": {"_lt": 15}}}, {C_TestD: {"points": {"_gte": 100}}}])
		.execute()
	)
	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()

	# Remove the with_none component query test and replace with regular component tests
	result = QueryBuilder.new(world).with_none([C_TestD]).execute()
	assert_array(result).has_size(1)
	assert_bool(result.has(entity4)).is_true()

	# Test multiple operators in same query
	result = (
		QueryBuilder.new(world).with_all([ {C_TestC: {"value": {"_gte": 20, "_lte": 25}}}]).execute()
	)
	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity3)).is_true()

	# Test combination of regular components and component queries
	result = (
		QueryBuilder.new(world).with_all([C_TestD, {C_TestC: {"value": {"_gt": 20}}}]).execute()
	)
	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity3)).is_true()

	# Test _in and _nin operators
	result = QueryBuilder.new(world).with_all([ {C_TestC: {"value": {"_in": [10, 25]}}}]).execute()
	assert_array(result).has_size(3)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_true()

	# Test complex combination of queries without with_none queries
	result = (
		QueryBuilder
		.new(world)
		.with_all([ {C_TestC: {"value": {"_gte": 25}}}])
		.with_any([ {C_TestD: {"points": {"_gt": 75}}}, {C_TestD: {"points": {"_lt": 30}}}])
		.with_none([C_TestE])
		.execute()
	) # Only use simple component exclusion
	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity3)).is_true()

	# Test empty value matching
	result = QueryBuilder.new(world).with_all([ {C_TestC: {}}]).execute()
	assert_array(result).has_size(4) # Should match all entities with TestC

	# Test non-existent property
	result = QueryBuilder.new(world).with_all([ {C_TestC: {"non_existent": {"_eq": 10}}}]).execute()
	assert_array(result).has_size(0) # Should match no entities

	# Test empty world query with component query property
	result = (
		QueryBuilder
		.new(world)
		.with_all([ {C_TestC: {"non_existent": {"_eq": 10}}}, C_TestD, C_TestE, C_TestA])
		.execute()
	)
	assert_array(result).has_size(0) # Should match no entities


func test_query_entities_groups():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	entity1.add_component(C_TestA.new())
	entity2.add_component(C_TestB.new())
	entity3.add_component(C_TestC.new())

	# Add entities to groups
	entity1.add_to_group("Player")
	entity2.add_to_group("Enemy")
	entity3.add_to_group("Enemy")
	entity3.add_to_group("NPC")

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Test with_group for "Player"
	var result = QueryBuilder.new(world).with_group(["Player"]).execute()
	assert_array(result).has_size(1)
	assert_bool(result.has(entity1)).is_true()

	# Verify entity1 with C_TestA in "Player"
	var check_player_a = (
		QueryBuilder.new(world).with_all([C_TestA]).with_group(["Player"]).execute()
	)
	assert_array(check_player_a).has_size(1)
	assert_bool(check_player_a.has(entity1)).is_true()

	# Test with_group for "Enemy"
	result = QueryBuilder.new(world).with_group(["Enemy"]).execute()
	assert_array(result).has_size(2)
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_true()

	# Verify entity2 with C_TestB in "Enemy"
	var check_enemy_b = QueryBuilder.new(world).with_all([C_TestB]).with_group(["Enemy"]).execute()
	assert_array(check_enemy_b).has_size(1)
	assert_bool(check_enemy_b.has(entity2)).is_true()

	# Verify entity3 with C_TestC in "Enemy"
	var check_enemy_c = QueryBuilder.new(world).with_all([C_TestC]).with_group(["Enemy"]).execute()
	assert_array(check_enemy_c).has_size(1)
	assert_bool(check_enemy_c.has(entity3)).is_true()

	# Test without_group excluding "NPC"
	result = QueryBuilder.new(world).with_group(["Enemy"]).without_group(["NPC"]).execute()
	assert_array(result).has_size(1)
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_false()

	# Verify excluding "NPC" removes entity3
	var check_enemy_c_no_npc = (
		QueryBuilder
		.new(world)
		.with_all([C_TestC])
		.with_group(["Enemy"])
		.without_group(["NPC"])
		.execute()
	)
	assert_array(check_enemy_c_no_npc).has_size(0)


#func test_query_caching():
	## Setup test entities
	#var entities = []
	#for i in range(1000): # Create a large number of entities for performance testing
		#var entity = Entity.new()
		#if i % 2 == 0:
			#entity.add_component(C_TestA.new())
		#if i % 3 == 0:
			#entity.add_component(C_TestB.new())
		#if i % 4 == 0:
			#entity.add_component(C_TestC.new())
		#entities.append(entity)
	#world.add_entities(entities)
#
	#var query = QueryBuilder.new(world)
	#query.with_all([C_TestA, C_TestB])
#
	## First execution - uncached
	#var time_start = Time.get_ticks_usec()
	#var result1 = query.execute()
	#var uncached_time = Time.get_ticks_usec() - time_start
#
	## Second execution - should use cache
	#time_start = Time.get_ticks_usec()
	#var result2 = query.execute()
	#var cached_time = Time.get_ticks_usec() - time_start
#
	## Verify results are identical
	#assert_array(result1).is_equal(result2)
#
	## Verify cache is faster (should be significantly faster)
	#assert_bool(cached_time < uncached_time).is_true()
	#print("Uncached query time: %d ns" % uncached_time)
	#print("Cached query time: %d ns" % cached_time)
	#print("Cache speedup: %.2fx" % (float(uncached_time) / max(cached_time, 1)))
#
	## Test cache invalidation
	#var new_entity = Entity.new()
	#new_entity.add_component(C_TestA.new())
	#new_entity.add_component(C_TestB.new())
	#world.add_entity(new_entity)
#
	#query.invalidate_cache()
	#var result3 = query.execute()
	## Verify new entity is included after cache invalidation
	#assert_bool(result3.has(new_entity)).is_true()
	#assert_int(result3.size()).is_equal(result2.size() + 1)
#
	## Test that modifying an entity's components invalidates relevant queries
	#var test_entity = result2[0]
	#test_entity.remove_component(C_TestA)
#
	#query.invalidate_cache()
	#var result4 = query.execute()
	#assert_bool(result4.has(test_entity)).is_false()
	#assert_int(result4.size()).is_equal(result3.size() - 1)
#

func test_query_cache_with_component_queries():
	# Setup test entities with varying component values
	var entities = []
	for i in range(100):
		var entity = Entity.new()
		entity.add_component(C_TestC.new(i)) # Each entity has unique TestC value
		world.add_entity(entity)
		entities.append(entity)

	var query = QueryBuilder.new(world)
	query.with_all([ {C_TestC: {"value": {"_gt": 50}}}])

	# First execution - uncached
	var time_start = Time.get_ticks_usec()
	var result1 = query.execute()
	var uncached_time = Time.get_ticks_usec() - time_start

	# Second execution - should use cache
	time_start = Time.get_ticks_usec()
	var result2 = query.execute()
	var cached_time = Time.get_ticks_usec() - time_start

	# Verify results
	assert_array(result1).is_equal(result2)
	assert_int(result1.size()).is_equal(49) # Should have entities with values 51-99

	# Verify cache is faster
	assert_bool(cached_time < uncached_time).is_true()
	print("Component query uncached time: %d ns" % uncached_time)
	print("Component query cached time: %d ns" % cached_time)
	print("Component query cache speedup: %.2fx" % (float(uncached_time) / max(cached_time, 1)))

	# Test cache invalidation with component value changes
	var target_entity = result1[0]
	var comp = target_entity.get_component(C_TestC)
	comp.value = 25 # Change to value that shouldn't match query

	query.invalidate_cache()
	var result3 = query.execute()
	assert_bool(result3.has(target_entity)).is_false()
	assert_int(result3.size()).is_equal(result2.size() - 1)


# Tests for relationship querying bug where with_relationship and without_relationship return same results
func test_with_relationship_vs_without_relationship_basic():
	# Create entities with and without relationships
	var entity_with_rel = Entity.new()
	var entity_without_rel = Entity.new()
	var target = Entity.new()

	# Only entity_with_rel has a relationship
	entity_with_rel.add_relationship(Relationship.new(C_TestA.new(), target))

	world.add_entity(entity_with_rel)
	world.add_entity(entity_without_rel)
	world.add_entity(target)

	# Test with_relationship - should only return entity_with_rel
	var with_result = QueryBuilder.new(world).with_relationship([Relationship.new(C_TestA.new(), null)]).execute()
	assert_array(with_result).has_size(1)
	assert_bool(with_result.has(entity_with_rel)).is_true()
	assert_bool(with_result.has(entity_without_rel)).is_false()

	# Test without_relationship - should only return entity_without_rel (and target)
	var without_result = QueryBuilder.new(world).without_relationship([Relationship.new(C_TestA.new(), null)]).execute()
	assert_bool(without_result.has(entity_with_rel)).is_false()
	assert_bool(without_result.has(entity_without_rel)).is_true()

	# These should NOT be equal!
	assert_bool(with_result.size() == without_result.size()).is_false()


func test_with_relationship_null_target():
	# Test the exact case from the bug report
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target = Entity.new()

	# Add relationship to only entity1 and entity2
	entity1.add_relationship(Relationship.new(C_TestA.new(), target))
	entity2.add_relationship(Relationship.new(C_TestA.new(), target))
	# entity3 has NO relationships

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(target)

	# Query with null target (wildcard) should find entities with ANY target for this relationship
	var result = QueryBuilder.new(world).with_relationship([Relationship.new(C_TestA.new(), null)]).execute()

	# Should only find entity1 and entity2
	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_false()
	assert_bool(result.has(target)).is_false()


func test_without_relationship_null_target():
	# Test without_relationship with null target
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target = Entity.new()

	# Add relationship to only entity1 and entity2
	entity1.add_relationship(Relationship.new(C_TestA.new(), target))
	entity2.add_relationship(Relationship.new(C_TestA.new(), target))
	# entity3 has NO relationships

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(target)

	# Query WITHOUT this relationship should find only entity3 and target
	var result = QueryBuilder.new(world).without_relationship([Relationship.new(C_TestA.new(), null)]).execute()

	# Should NOT find entity1 or entity2
	assert_bool(result.has(entity1)).is_false()
	assert_bool(result.has(entity2)).is_false()
	# Should find entity3 and target
	assert_bool(result.has(entity3)).is_true()
	assert_bool(result.has(target)).is_true()


func test_with_relationship_wildcard_target():
	# Test with ECS.wildcard explicitly
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target = Entity.new()

	entity1.add_relationship(Relationship.new(C_TestA.new(), target))
	entity2.add_relationship(Relationship.new(C_TestA.new(), target))

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(target)

	# Use ECS.wildcard explicitly
	var result = QueryBuilder.new(world).with_relationship([Relationship.new(C_TestA.new(), ECS.wildcard)]).execute()

	assert_array(result).has_size(2)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_false()


func test_with_relationship_specific_entity_target():
	# Test with a specific entity as target
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target_a = Entity.new()
	var target_b = Entity.new()

	entity1.add_relationship(Relationship.new(C_TestA.new(), target_a))
	entity2.add_relationship(Relationship.new(C_TestA.new(), target_b))
	# entity3 has no relationships

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(target_a)
	world.add_entity(target_b)

	# Query for entities with relationship to target_a specifically
	var result = QueryBuilder.new(world).with_relationship([Relationship.new(C_TestA.new(), target_a)]).execute()

	assert_array(result).has_size(1)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_false()
	assert_bool(result.has(entity3)).is_false()


func test_with_relationship_entity_archetype_target():
	# Test with entity archetype as target
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target = Entity.new() # Generic Entity type

	entity1.add_relationship(Relationship.new(C_TestA.new(), Entity))
	entity2.add_relationship(Relationship.new(C_TestA.new(), target))
	# entity3 has no relationships

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(target)

	# Query for entities with relationship to Entity archetype
	var result = QueryBuilder.new(world).with_relationship([Relationship.new(C_TestA.new(), Entity)]).execute()

	# Should find both entity1 and entity2 (entity2's target is an Entity instance)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_true()
	assert_bool(result.has(entity3)).is_false()


# Tests for with_group bug where nonexistent groups return all entities
func test_with_group_basic():
	# Create entities with and without groups
	var entity_in_group = Entity.new()
	var entity_not_in_group = Entity.new()

	entity_in_group.add_to_group("TestGroup")
	# entity_not_in_group is not in any group

	world.add_entity(entity_in_group)
	world.add_entity(entity_not_in_group)

	# Query for entities in "TestGroup"
	var result = QueryBuilder.new(world).with_group(["TestGroup"]).execute()

	assert_array(result).has_size(1)
	assert_bool(result.has(entity_in_group)).is_true()
	assert_bool(result.has(entity_not_in_group)).is_false()


func test_with_group_nonexistent_group():
	# Test the exact bug: querying for a nonexistent group should return NO entities
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	entity1.add_to_group("GroupA")
	entity2.add_to_group("GroupB")
	# entity3 has no groups

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Query for a group that DOES NOT EXIST
	var result = QueryBuilder.new(world).with_group(["NonexistentGroup"]).execute()

	# Should return ZERO entities, not all entities!
	assert_array(result).has_size(0)
	assert_bool(result.has(entity1)).is_false()
	assert_bool(result.has(entity2)).is_false()
	assert_bool(result.has(entity3)).is_false()


func test_with_group_vs_without_group():
	# Test that with_group and without_group return different results
	var entity_in_group = Entity.new()
	var entity_not_in_group = Entity.new()

	entity_in_group.add_to_group("TestGroup")

	world.add_entity(entity_in_group)
	world.add_entity(entity_not_in_group)

	# with_group should find only entity_in_group
	var with_result = QueryBuilder.new(world).with_group(["TestGroup"]).execute()
	assert_array(with_result).has_size(1)
	assert_bool(with_result.has(entity_in_group)).is_true()

	# without_group should find only entity_not_in_group
	var without_result = QueryBuilder.new(world).without_group(["TestGroup"]).execute()
	assert_array(without_result).has_size(1)
	assert_bool(without_result.has(entity_not_in_group)).is_true()

	# These should be DIFFERENT!
	assert_bool(with_result.size() == without_result.size()).is_true() # Both have 1 entity
	assert_bool(with_result.has(entity_in_group)).is_true()
	assert_bool(without_result.has(entity_not_in_group)).is_true()
	# But they should not contain the same entities
	assert_bool(with_result.has(entity_not_in_group)).is_false()
	assert_bool(without_result.has(entity_in_group)).is_false()


func test_with_all_and_with_relationship_combination():
	# Test combining component and relationship queries
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()
	var target = Entity.new()

	# entity1 has component A and relationship
	entity1.add_component(C_TestA.new())
	entity1.add_relationship(Relationship.new(C_TestB.new(), target))

	# entity2 has only component A
	entity2.add_component(C_TestA.new())

	# entity3 has only relationship
	entity3.add_relationship(Relationship.new(C_TestB.new(), target))

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)
	world.add_entity(target)

	# Query for entities with both component A and the relationship
	var result = (
		QueryBuilder.new(world)
		.with_all([C_TestA])
		.with_relationship([Relationship.new(C_TestB.new(), null)])
		.execute()
	)

	# Should only find entity1
	assert_array(result).has_size(1)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_false()
	assert_bool(result.has(entity3)).is_false()


func test_with_all_and_with_group_combination():
	# Test combining component and group queries
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	# entity1 has component A and is in group
	entity1.add_component(C_TestA.new())
	entity1.add_to_group("TestGroup")

	# entity2 has only component A
	entity2.add_component(C_TestA.new())

	# entity3 is only in group
	entity3.add_to_group("TestGroup")

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	# Query for entities with both component A and in the group
	var result = QueryBuilder.new(world).with_all([C_TestA]).with_group(["TestGroup"]).execute()

	# Should only find entity1
	assert_array(result).has_size(1)
	assert_bool(result.has(entity1)).is_true()
	assert_bool(result.has(entity2)).is_false()
	assert_bool(result.has(entity3)).is_false()


func test_with_any_filters_instead_of_broadening():
	# This test documents current semantics of with_any(): it REQUIRES at least one of the listed
	# components to be present (logical OR constraint) in addition to with_all()/relationships,
	# instead of broadening the result set. Users sometimes expect with_any() to behave like
	# "optionally include these components" (i.e. a union of baseline results plus entities that
	# have the optional components). That is NOT the implemented behavior.
	#
	# Setup:
	#  - Two entities (e1, e2) both have C_TestA (acting like C_Health) and a damage relationship
	#  - Only e2 has C_TestC (acting like C_Breakable)
	# Baseline query (with_all + relationship) returns BOTH entities.
	# Adding with_any([C_TestC]) returns ONLY e2 (entities must now also have at least one of the any-list)
	# If no entity had C_TestC then result would become empty
	var e1 = Entity.new()
	var e2 = Entity.new()
	var target = Entity.new() # Relationship target entity

	# Components analogous to C_Health and C_Breakable
	e1.add_component(C_TestA.new())
	e2.add_component(C_TestA.new())
	e2.add_component(C_TestC.new()) # Only e2 is "breakable"

	# Relationship marker analogous to R_Damaged_Any (using C_TestB as marker)
	e1.add_relationship(Relationship.new(C_TestB.new(), target))
	e2.add_relationship(Relationship.new(C_TestB.new(), target))

	world.add_entity(e1)
	world.add_entity(e2)
	world.add_entity(target)

	# Baseline query: both entities match (have C_TestA + damage relationship)
	var baseline = (
		QueryBuilder
		.new(world)
		.with_all([C_TestA])
		.with_relationship([Relationship.new(C_TestB.new(), null)])
		.execute()
	) as Array[Entity]
	assert_int(baseline.size()).is_equal(2)
	assert_bool(baseline.has(e1)).is_true()
	assert_bool(baseline.has(e2)).is_true()

	# Adding with_any([C_TestC]) NARROWS results to just e2 (must have at least one any-component)
	var narrowed = (
		QueryBuilder
		.new(world)
		.with_all([C_TestA])
		.with_relationship([Relationship.new(C_TestB.new(), null)])
		.with_any([C_TestC])
		.execute()
	) as Array[Entity]
	assert_int(narrowed.size()).is_equal(1)
	assert_bool(narrowed.has(e2)).is_true()
	assert_bool(narrowed.has(e1)).is_false()