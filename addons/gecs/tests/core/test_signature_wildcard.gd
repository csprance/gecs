class_name TestSignatureWildcard
extends GdUnitTestSuite
## Test suite for signature computation with relationship pairs,
## QueryCacheKey pair encoding, stable entity IDs, and wildcard index.
##
## Covers SIGX-01 through SIGX-04.

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Test 1 (SIGX-01 basic): An entity with a relationship produces a different signature
## than an entity with only the same components and no relationships.
func test_signature_differs_with_relationship():
	var entity_a = Entity.new()
	var entity_b = Entity.new()
	var target = Entity.new()

	world.add_entity(entity_a)
	world.add_entity(entity_b)
	world.add_entity(target)

	entity_a.add_component(C_TestA.new())
	entity_b.add_component(C_TestA.new())

	# Add a relationship only to entity_a (directly to array for signature testing)
	var rel = Relationship.new(C_TestA.new(), target)
	entity_a.relationships.append(rel)

	var sig_a = world._calculate_entity_signature(entity_a)
	var sig_b = world._calculate_entity_signature(entity_b)

	assert_int(sig_a).is_not_equal(sig_b)


## Test 2 (SIGX-01 different targets): Two entities with the same relation type
## but different entity targets produce different signatures.
func test_signature_differs_with_different_targets():
	var entity_a = Entity.new()
	var entity_b = Entity.new()
	var target_1 = Entity.new()
	var target_2 = Entity.new()

	world.add_entity(entity_a)
	world.add_entity(entity_b)
	world.add_entity(target_1)
	world.add_entity(target_2)

	entity_a.add_component(C_TestA.new())
	entity_b.add_component(C_TestA.new())

	entity_a.relationships.append(Relationship.new(C_TestA.new(), target_1))
	entity_b.relationships.append(Relationship.new(C_TestA.new(), target_2))

	var sig_a = world._calculate_entity_signature(entity_a)
	var sig_b = world._calculate_entity_signature(entity_b)

	assert_int(sig_a).is_not_equal(sig_b)


## Test 3 (SIGX-01 same relationships): Two entities with identical components
## and identical relationships produce the SAME signature.
func test_signature_same_with_identical_relationships():
	var entity_a = Entity.new()
	var entity_b = Entity.new()
	var target = Entity.new()

	world.add_entity(entity_a)
	world.add_entity(entity_b)
	world.add_entity(target)

	entity_a.add_component(C_TestA.new())
	entity_b.add_component(C_TestA.new())

	entity_a.relationships.append(Relationship.new(C_TestA.new(), target))
	entity_b.relationships.append(Relationship.new(C_TestA.new(), target))

	var sig_a = world._calculate_entity_signature(entity_a)
	var sig_b = world._calculate_entity_signature(entity_b)

	assert_int(sig_a).is_equal(sig_b)


## Test 4 (SIGX-02 pair encoding): QueryCacheKey.build() with relationship to entityA
## produces a different hash than with the same relation type but entityB target.
func test_query_cache_key_different_targets():
	var entity_a = Entity.new()
	var entity_b = Entity.new()

	world.add_entity(entity_a)
	world.add_entity(entity_b)

	var rel_a = Relationship.new(C_TestA.new(), entity_a)
	var rel_b = Relationship.new(C_TestA.new(), entity_b)

	var hash_a = QueryCacheKey.build([], [], [], [rel_a])
	var hash_b = QueryCacheKey.build([], [], [], [rel_b])

	assert_int(hash_a).is_not_equal(hash_b)


## Test 5 (SIGX-02 cross-pair collision prevention): Different pair assignments
## produce different hashes — pair identity is maintained.
func test_query_cache_key_cross_pair_no_collision():
	var entity_1 = Entity.new()
	var entity_2 = Entity.new()

	world.add_entity(entity_1)
	world.add_entity(entity_2)

	# Set 1: (C_TestA, entity_1), (C_TestB, entity_2)
	var rel_set_1 = [
		Relationship.new(C_TestA.new(), entity_1),
		Relationship.new(C_TestB.new(), entity_2)
	]

	# Set 2: (C_TestA, entity_2), (C_TestB, entity_1) — swapped targets
	var rel_set_2 = [
		Relationship.new(C_TestA.new(), entity_2),
		Relationship.new(C_TestB.new(), entity_1)
	]

	var hash_1 = QueryCacheKey.build([], [], [], rel_set_1)
	var hash_2 = QueryCacheKey.build([], [], [], rel_set_2)

	assert_int(hash_1).is_not_equal(hash_2)


## Test 6 (SIGX-02 property-query exclusion): Query relationships with
## _is_query_relationship == true do NOT contribute to the structural hash.
func test_query_cache_key_excludes_property_queries():
	var entity_1 = Entity.new()
	world.add_entity(entity_1)

	var structural_rel = Relationship.new(C_TestA.new(), entity_1)
	# Create a query relationship (dictionary form sets _is_query_relationship = true)
	var query_rel = Relationship.new({C_TestB: {"value": {"_gt": 5}}}, null)

	# Hash with structural only
	var hash_structural = QueryCacheKey.build([], [], [], [structural_rel])
	# Hash with structural + query relationship (query rel should be ignored)
	var hash_both = QueryCacheKey.build([], [], [], [structural_rel, query_rel])

	assert_int(hash_structural).is_equal(hash_both)


## Test 7 (SIGX-03 wildcard index populated): After creating an archetype with rel:// keys,
## _relation_type_archetype_index maps the relation resource paths to the archetype.
func test_wildcard_index_populated_on_archetype_creation():
	var rel_key = "rel://res://addons/gecs/tests/components/c_test_a.gd::entity#1"
	var comp_types = ["res://addons/gecs/tests/components/c_test_a.gd", rel_key]
	var sig = QueryCacheKey.build([C_TestA], [], []) # Simplified sig for testing

	var archetype = world._get_or_create_archetype(sig, comp_types)

	# The wildcard index should map the relation path to the archetype
	var rel_path = "res://addons/gecs/tests/components/c_test_a.gd"
	assert_bool(world._relation_type_archetype_index.has(rel_path)).is_true()
	assert_bool(world._relation_type_archetype_index[rel_path].has(archetype.signature)).is_true()
	assert_object(world._relation_type_archetype_index[rel_path][archetype.signature]).is_same(archetype)


## Test 8 (SIGX-04 wildcard index cleanup): When an archetype is deleted,
## its entries are removed from _relation_type_archetype_index.
func test_wildcard_index_cleaned_on_archetype_deletion():
	var rel_key = "rel://res://addons/gecs/tests/components/c_test_b.gd::entity#2"
	var comp_types = ["res://addons/gecs/tests/components/c_test_b.gd", rel_key]
	var sig = QueryCacheKey.build([C_TestB], [], []) # Simplified sig for testing

	var archetype = world._get_or_create_archetype(sig, comp_types)
	var rel_path = "res://addons/gecs/tests/components/c_test_b.gd"

	# Confirm the index is populated
	assert_bool(world._relation_type_archetype_index.has(rel_path)).is_true()

	# Delete the archetype
	world._delete_archetype(archetype)

	# The relation should be removed from the index (or the entire entry gone if empty)
	if world._relation_type_archetype_index.has(rel_path):
		assert_bool(world._relation_type_archetype_index[rel_path].has(sig)).is_false()


## Test 9 (stable entity ID): An entity registered in a World receives a unique
## integer ecs_id (> 0). Two different entities get different values.
func test_stable_entity_id_assigned():
	var entity_a = Entity.new()
	var entity_b = Entity.new()

	# Before registration, ecs_id should be 0
	assert_int(entity_a.ecs_id).is_equal(0)
	assert_int(entity_b.ecs_id).is_equal(0)

	world.add_entity(entity_a)
	world.add_entity(entity_b)

	# After registration, should have unique positive IDs
	assert_int(entity_a.ecs_id).is_greater(0)
	assert_int(entity_b.ecs_id).is_greater(0)
	assert_int(entity_a.ecs_id).is_not_equal(entity_b.ecs_id)


## Test 10 (slot key uses stable ID): The slot key for an entity-targeted relationship
## uses "entity#<ecs_id>" format, not "entity#<instance_id>".
func test_slot_key_uses_stable_id():
	var entity = Entity.new()
	var target = Entity.new()

	world.add_entity(entity)
	world.add_entity(target)

	var rel = Relationship.new(C_TestA.new(), target)
	var slot_key = world._relationship_slot_key(rel)

	# Should contain entity#<ecs_id>, not instance_id
	var expected_suffix = "entity#" + str(target.ecs_id)
	assert_str(slot_key).contains(expected_suffix)
	assert_str(slot_key).starts_with("rel://")
	assert_str(slot_key).contains("::")

	# Ensure it does NOT use instance_id (they should differ from ecs_id)
	var instance_suffix = "entity#" + str(target.get_instance_id())
	if target.ecs_id != target.get_instance_id():
		assert_str(slot_key).not_contains(instance_suffix)
