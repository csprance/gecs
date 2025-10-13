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

func test_serialize_entity_with_basic_relationship():
	# Create two entities with a basic relationship
	var entity_a = Entity.new()
	entity_a.name = "EntityA"
	entity_a.add_component(C_TestA.new())
	
	var entity_b = Entity.new()
	entity_b.name = "EntityB"
	entity_b.add_component(C_TestB.new())
	
	# Create relationship: A -> B
	var relationship = Relationship.new(C_TestC.new(), entity_b)
	entity_a.add_relationship(relationship)
	
	world.add_entity(entity_a)
	world.add_entity(entity_b)
	
	# Serialize only entity A (entity B should be auto-included)
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	
	# Validate serialization
	assert_that(serialized_data).is_not_null()
	assert_that(serialized_data.entities).has_size(2) # Both A and B should be included
	
	# Check that entity B is marked as auto-included
	var entity_a_data = serialized_data.entities.filter(func(e): return e.entity_name == "EntityA")[0]
	var entity_b_data = serialized_data.entities.filter(func(e): return e.entity_name == "EntityB")[0]
	
	assert_that(entity_a_data.auto_included).is_false() # Original query entity
	assert_that(entity_b_data.auto_included).is_true() # Auto-included dependency
	
	# Check relationship data
	assert_that(entity_a_data.relationships).has_size(1)
	var rel_data = entity_a_data.relationships[0]
	assert_that(rel_data.target_type).is_equal("Entity")
	assert_that(rel_data.target_entity_id).is_equal(entity_b.id)

func test_deserialize_entity_with_basic_relationship():
	# Create and serialize entities with relationship
	var entity_a = Entity.new()
	entity_a.name = "EntityA"
	entity_a.add_component(C_TestA.new())
	
	var entity_b = Entity.new()
	entity_b.name = "EntityB"
	entity_b.add_component(C_TestB.new())
	
	var relationship = Relationship.new(C_TestC.new(), entity_b)
	entity_a.add_relationship(relationship)
	
	world.add_entity(entity_a)
	world.add_entity(entity_b)
	
	# Serialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	
	# Save and load
	var file_path = "res://reports/test_relationship_basic.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)
	
	# Validate deserialization
	assert_that(deserialized_entities).has_size(2)
	
	var des_entity_a = deserialized_entities.filter(func(e): return e.name == "EntityA")[0]
	var des_entity_b = deserialized_entities.filter(func(e): return e.name == "EntityB")[0]
	
	# Check that relationships are restored
	assert_that(des_entity_a.relationships).has_size(1)
	var des_relationship = des_entity_a.relationships[0]
	assert_that(des_relationship.target).is_equal(des_entity_b)
	
	# Cleanup
	for entity in deserialized_entities:
		auto_free(entity)

func test_circular_relationships():
	# Create entities with circular relationships: A -> B -> A
	var entity_a = Entity.new()
	entity_a.name = "EntityA"
	entity_a.add_component(C_TestA.new())
	
	var entity_b = Entity.new()
	entity_b.name = "EntityB"
	entity_b.add_component(C_TestB.new())
	
	# Create circular relationships
	var rel_a_to_b = Relationship.new(C_TestC.new(), entity_b)
	var rel_b_to_a = Relationship.new(C_TestD.new(), entity_a)
	
	entity_a.add_relationship(rel_a_to_b)
	entity_b.add_relationship(rel_b_to_a)
	
	world.add_entity(entity_a)
	world.add_entity(entity_b)
	
	# Serialize starting from entity A
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	
	# Should include both entities (no infinite loop)
	assert_that(serialized_data.entities).has_size(2)
	
	# Deserialize and validate
	var file_path = "res://reports/test_relationship_circular.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)
	
	assert_that(deserialized_entities).has_size(2)
	
	var des_a = deserialized_entities.filter(func(e): return e.name == "EntityA")[0]
	var des_b = deserialized_entities.filter(func(e): return e.name == "EntityB")[0]
	
	# Validate circular relationships are restored
	assert_that(des_a.relationships).has_size(1)
	assert_that(des_b.relationships).has_size(1)
	assert_that(des_a.relationships[0].target).is_equal(des_b)
	assert_that(des_b.relationships[0].target).is_equal(des_a)
	
	# Cleanup
	for entity in deserialized_entities:
		auto_free(entity)

func test_component_target_relationship():
	# Create entity with component-based relationship
	var entity = Entity.new()
	entity.name = "EntityWithComponentRel"
	entity.add_component(C_TestA.new())
	
	# Create relationship with Component target
	var target_component = C_TestB.new()
	# Note: Components don't have a 'name' property, so we don't set it
	var relationship = Relationship.new(C_TestC.new(), target_component)
	entity.add_relationship(relationship)
	
	world.add_entity(entity)
	
	# Serialize and deserialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	
	var file_path = "res://reports/test_relationship_component.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)
	
	# Validate
	assert_that(deserialized_entities).has_size(1)
	var des_entity = deserialized_entities[0]
	assert_that(des_entity.relationships).has_size(1)
	
	var des_relationship = des_entity.relationships[0]
	assert_that(des_relationship.target is C_TestB).is_true()
	
	# Cleanup
	auto_free(des_entity)

func test_script_target_relationship():
	# Create entity with script archetype relationship
	var entity = Entity.new()
	entity.name = "EntityWithScriptRel"
	entity.add_component(C_TestA.new())
	
	# Create relationship with Script target
	var relationship = Relationship.new(C_TestC.new(), C_TestB)
	entity.add_relationship(relationship)
	
	world.add_entity(entity)
	
	# Serialize and deserialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	
	var file_path = "res://reports/test_relationship_script.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)
	
	# Validate
	assert_that(deserialized_entities).has_size(1)
	var des_entity = deserialized_entities[0]
	assert_that(des_entity.relationships).has_size(1)
	
	var des_relationship = des_entity.relationships[0]
	assert_that(des_relationship.target).is_equal(C_TestB)
	
	# Cleanup
	auto_free(des_entity)

func test_id_persistence_across_save_load_cycles():
	# Create entity and save its UUID
	var entity = Entity.new()
	entity.name = "UUIDTestEntity"
	entity.add_component(C_TestA.new())
	
	world.add_entity(entity)
	var original_id = entity.id
	
	# Serialize, save, and load multiple times
	var query = world.query.with_all([C_TestA])
	
	for cycle in range(3):
		var serialized_data = ECS.serialize(query)
		var file_path = "res://reports/test_id_cycle_" + str(cycle) + ".tres"
		ECS.save(serialized_data, file_path)
		
		var deserialized_entities = ECS.deserialize(file_path)
		assert_that(deserialized_entities).has_size(1)
		
		var des_entity = deserialized_entities[0]
		assert_that(des_entity.id).is_equal(original_id)
		
		# Cleanup
		auto_free(des_entity)

func test_deep_relationship_chain():
	# Create a chain: A -> B -> C -> D
	var entities = []
	for i in range(4):
		var entity = Entity.new()
		entity.name = "Entity" + String.num(i)
		entity.add_component(C_TestA.new())
		entities.append(entity)
		world.add_entity(entity)
	
	# Create chain relationships
	for i in range(3):
		var relationship = Relationship.new(C_TestC.new(), entities[i + 1])
		entities[i].add_relationship(relationship)
	
	# Serialize starting from first entity only - create a query that matches just the first entity
	# We'll use a unique component for the first entity
	entities[0].add_component(C_TestE.new()) # Add unique component to first entity
	var query = world.query.with_all([C_TestE])
	var serialized_data = ECS.serialize(query)
	
	# Should auto-include entire chain
	assert_that(serialized_data.entities).has_size(4)
	
	# Verify auto-inclusion flags
	var auto_included_count = 0
	var original_entity_count = 0
	
	for entity_data in serialized_data.entities:
		if entity_data.auto_included:
			auto_included_count += 1
		else:
			original_entity_count += 1
	
	assert_that(original_entity_count).is_equal(1) # Only one entity from original query
	assert_that(auto_included_count).is_equal(3) # Three entities auto-included
	
	# Test deserialization
	var file_path = "res://reports/test_relationship_chain.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)
	
	assert_that(deserialized_entities).has_size(4)
	
	# Cleanup
	for entity in deserialized_entities:
		auto_free(entity)

func test_backward_compatibility_no_relationships():
	# Test that entities without relationships still work
	var entity = Entity.new()
	entity.name = "NoRelationshipEntity"
	entity.add_component(C_TestA.new())
	
	world.add_entity(entity)
	
	# Serialize and deserialize
	var query = world.query.with_all([C_TestA])
	var serialized_data = ECS.serialize(query)
	
	var file_path = "res://reports/test_no_relationships.tres"
	ECS.save(serialized_data, file_path)
	var deserialized_entities = ECS.deserialize(file_path)
	
	# Should work normally
	assert_that(deserialized_entities).has_size(1)
	var des_entity = deserialized_entities[0]
	assert_that(des_entity.name).is_equal("NoRelationshipEntity")
	assert_that(des_entity.relationships).has_size(0)
	assert_that(des_entity.id).is_not_equal("")
	
	# Cleanup
	auto_free(des_entity)
