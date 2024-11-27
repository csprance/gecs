extends GdUnitTestSuite

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const C_TestD = preload("res://addons/gecs/tests/components/c_test_d.gd")
const C_TestE = preload("res://addons/gecs/tests/components/c_test_e.gd")
const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")

var runner : GdUnitSceneRunner
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
	var result = QueryBuilder.new(world).with_all([C_TestA, C_TestB]).with_any([C_TestC, C_TestD]).execute()
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
	var result = QueryBuilder.new(world).with_all([C_TestA, C_TestB]).with_any([C_TestC, C_TestE]).with_none([C_TestD]).execute()
	
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

	# Query with no components specified should return no entities
	var result = QueryBuilder.new(world).execute()
	assert_array(result).is_empty()

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
