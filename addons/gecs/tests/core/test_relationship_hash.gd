extends GdUnitTestSuite

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")

var runner: GdUnitSceneRunner
var world: World

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	world.purge(false)

func test_relationship_string_representation():
	# Test that two semantically identical relationships produce the same string
	var rel1 = Relationship.new(C_TestA.new(10), null)
	var rel2 = Relationship.new(C_TestA.new(10), null)

	# These should produce the same string representation for cache keys
	var str1 = str(rel1)
	var str2 = str(rel2)

	print("rel1 string: ", str1)
	print("rel2 string: ", str2)

	# They won't be equal as objects (different instances)
	assert_bool(rel1 == rel2).is_false()

	# But they should match semantically
	assert_bool(rel1.matches(rel2)).is_true()

	# The problem: their string representations are different!
	# This breaks query caching
	print("Strings equal? ", str1 == str2)

func test_relationship_with_entity_targets():
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	entity1.name = "entity1"
	entity2.name = "entity2"
	world.add_entity(entity1)
	world.add_entity(entity2)

	var rel1 = Relationship.new(C_TestA.new(), entity1)
	var rel2 = Relationship.new(C_TestA.new(), entity1)
	var rel3 = Relationship.new(C_TestA.new(), entity2)

	print("rel1 with entity1: ", str(rel1))
	print("rel2 with entity1: ", str(rel2))
	print("rel3 with entity2: ", str(rel3))

	# Should match same entity
	assert_bool(rel1.matches(rel2)).is_true()
	# Should not match different entity
	assert_bool(rel1.matches(rel3)).is_false()

func test_query_cache_key_with_relationships():
	# This test shows the actual problem with query caching
	var entity = Entity.new()
	world.add_entity(entity)
	entity.add_component(C_TestA.new(5))
	entity.add_relationship(Relationship.new(C_TestB.new(), null))

	# These two queries are semantically identical
	var query1 = world.query.with_relationship([Relationship.new(C_TestB.new(), null)])
	var query2 = world.query.with_relationship([Relationship.new(C_TestB.new(), null)])

	var key1 = query1.to_string()
	var key2 = query2.to_string()

	print("Query1 cache key: ", key1)
	print("Query2 cache key: ", key2)

	# These SHOULD be the same for proper caching
	# But they're probably not because Relationship lacks to_string()
	print("Cache keys equal? ", key1 == key2)

func test_relationship_matching_with_multiple_relationships():
	# Test that relationship matching works regardless of order in relationships list
	var target_entity = Entity.new()
	target_entity.name = "target"
	world.add_entity(target_entity)

	var entity = Entity.new()
	entity.name = "test_entity"
	world.add_entity(entity)

	# Add multiple relationships in specific order
	entity.add_relationship(Relationship.new(C_TestA.new(1), target_entity))
	entity.add_relationship(Relationship.new(C_TestA.new(2), target_entity))
	entity.add_relationship(Relationship.new(C_TestB.new(99), target_entity))

	print("Entity relationships count: ", entity.relationships.size())

	# Try to find the C_TestB relationship - it's at index 2
	var has_testb = entity.has_relationship(Relationship.new(C_TestB.new(), target_entity))
	print("Has C_TestB relationship (at end of list): ", has_testb)
	assert_bool(has_testb).is_true()

	# Now try when C_TestB is first
	var entity2 = Entity.new()
	entity2.name = "test_entity2"
	world.add_entity(entity2)

	entity2.add_relationship(Relationship.new(C_TestB.new(99), target_entity))
	entity2.add_relationship(Relationship.new(C_TestA.new(1), target_entity))
	entity2.add_relationship(Relationship.new(C_TestA.new(2), target_entity))

	var has_testb2 = entity2.has_relationship(Relationship.new(C_TestB.new(), target_entity))
	print("Has C_TestB relationship (at start of list): ", has_testb2)
	assert_bool(has_testb2).is_true()

	# Test the actual relationship objects match
	for i in range(entity.relationships.size()):
		var rel = entity.relationships[i]
		var test_rel = Relationship.new(C_TestB.new(), target_entity)
		print("Relationship[", i, "] matches test_rel: ", rel.matches(test_rel))
		print("  - Relation types: ", rel.relation.get_script().resource_path, " vs ", test_rel.relation.get_script().resource_path)
		print("  - Target IDs: ", rel.target.id if rel.target else "null", " vs ", test_rel.target.id if test_rel.target else "null")
		print("  - Targets same instance: ", rel.target == test_rel.target)

func test_query_with_multiple_relationships():
	# Test that queries find entities even when they have multiple relationships
	var target_entity = Entity.new()
	target_entity.name = "target"
	world.add_entity(target_entity)

	var entity1 = Entity.new()
	entity1.name = "entity1_single_rel"
	world.add_entity(entity1)
	entity1.add_relationship(Relationship.new(C_TestB.new(1), target_entity))

	var entity2 = Entity.new()
	entity2.name = "entity2_multi_rel"
	world.add_entity(entity2)
	entity2.add_relationship(Relationship.new(C_TestA.new(1), target_entity))
	entity2.add_relationship(Relationship.new(C_TestA.new(2), target_entity))
	entity2.add_relationship(Relationship.new(C_TestB.new(99), target_entity))

	var entity3 = Entity.new()
	entity3.name = "entity3_no_testb"
	world.add_entity(entity3)
	entity3.add_relationship(Relationship.new(C_TestA.new(5), target_entity))

	print("\n=== Query Test ===")
	print("entity1 relationships: ", entity1.relationships.size())
	print("entity2 relationships: ", entity2.relationships.size())
	print("entity3 relationships: ", entity3.relationships.size())

	# Query for entities with C_TestB relationship
	var query = world.query.with_relationship([Relationship.new(C_TestB.new(), target_entity)])
	var results = Array(query.execute())

	print("\nQuery results count: ", results.size())
	for ent in results:
		print("  - Found: ", ent.name)

	# Both entity1 and entity2 should be found
	assert_bool(results.has(entity1)).is_true()
	assert_bool(results.has(entity2)).is_true()
	assert_bool(results.has(entity3)).is_false()
	assert_int(results.size()).is_equal(2)
