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
	# Clean up any test files
	_cleanup_test_files()

func _cleanup_test_files():
	# Skip cleanup to allow inspection of .tres files in reports directory
	return

func test_basic_entity_serialization():
	# Create entity with basic components
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(C_SerializationTest.new(100, 9.99, "serialized", true, Vector2(3.0, 4.0), Vector3(5.0, 6.0, 7.0), Color.GREEN))
	entity.add_component(C_Persistent.new("Hero", 10, 85.5, Vector2(50.0, 100.0), ["shield", "bow"]))
	
	world.add_entity(entity)
	
	# Serialize the entity
	var query = world.query.with_all([C_SerializationTest])
	var serialized_data = ECS.serialize(query)
	
	# Validate serialized structure
	assert_that(serialized_data).is_not_null()
	assert_that(serialized_data.version).is_equal("0.1")
	assert_that(serialized_data.entities).has_size(1)
	
	var entity_data = serialized_data.entities[0]
	assert_that(entity_data.entity_name).is_equal("TestEntity")
	assert_that(entity_data.components).has_size(2)
	
	# Find components by type
	var serialization_component: C_SerializationTest
	var persistent_component: C_Persistent
	
	for component in entity_data.components:
		if component is C_SerializationTest:
			serialization_component = component
		elif component is C_Persistent:
			persistent_component = component
	
	# Validate component data
	assert_that(serialization_component).is_not_null()
	assert_that(serialization_component.int_value).is_equal(100)
	assert_that(serialization_component.float_value).is_equal(9.99)
	assert_that(serialization_component.string_value).is_equal("serialized")
	assert_that(serialization_component.bool_value).is_equal(true)
	
	assert_that(persistent_component).is_not_null()

func test_complex_data_serialization():
	# Create entity with complex data types
	var entity = E_ComplexSerializationTest.new()
	entity.name = "ComplexEntity"
	
	world.add_entity(entity)
	
	# Serialize the entity
	var query = world.query.with_all([C_ComplexSerializationTest])
	var serialized_data = ECS.serialize(query)
	
	# Validate complex data preservation
	var entity_data = serialized_data.entities[0]
	var complex_component: C_ComplexSerializationTest
	
	# Find the complex component
	for component in entity_data.components:
		if component is C_ComplexSerializationTest:
			complex_component = component
			break
	
	assert_that(complex_component).is_not_null()
	assert_that(complex_component.array_value).is_equal([10, 20, 30])
	assert_that(complex_component.string_array).is_equal(["alpha", "beta", "gamma"])
	assert_that(complex_component.dict_value).is_equal({"hp": 100, "mp": 50, "items": 3})
	assert_that(complex_component.empty_array).is_equal([])
	assert_that(complex_component.empty_dict).is_equal({})

func test_serialization_deserialization_round_trip():
	# Create multiple entities with different components
	var entity1 = E_SerializationTest.new()
	entity1.name = "Entity1"
	
	var entity2 = E_ComplexSerializationTest.new()
	entity2.name = "Entity2"
	
	world.add_entities([entity1, entity2])
	
	# Serialize entities with C_SerializationTest component
	var query = world.query.with_all([C_SerializationTest])
	var serialized_data = ECS.serialize(query)
	
	# Save to file using resource system
	var file_path = "res://reports/test_round_trip.tres"
	ECS.save(serialized_data, file_path)
	
	# Deserialize from file
	var deserialized_entities = ECS.deserialize(file_path)
	
	# Validate deserialized entities
	assert_that(deserialized_entities).has_size(2)
	
	# Check first entity
	var des_entity1 = deserialized_entities[0]
	assert_that(des_entity1.name).is_equal("Entity1")
	assert_that(des_entity1.has_component(C_SerializationTest)).is_true()
	assert_that(des_entity1.has_component(C_Persistent)).is_true()
	
	var des_comp1 = des_entity1.get_component(C_SerializationTest)
	assert_that(des_comp1.int_value).is_equal(42)
	assert_that(des_comp1.string_value).is_equal("test_string")
	
	var des_persistent1 = des_entity1.get_component(C_Persistent)
	assert_that(des_persistent1.player_name).is_equal("TestPlayer")
	assert_that(des_persistent1.level).is_equal(5)
	assert_that(des_persistent1.health).is_equal(75.0)
	
	# Check second entity
	var des_entity2 = deserialized_entities[1]
	assert_that(des_entity2.name).is_equal("Entity2")
	assert_that(des_entity2.has_component(C_ComplexSerializationTest)).is_true()
	assert_that(des_entity2.has_component(C_SerializationTest)).is_true()
	
	var des_complex = des_entity2.get_component(C_ComplexSerializationTest)
	assert_that(des_complex.array_value).is_equal([10, 20, 30])
	assert_that(des_complex.dict_value).is_equal({"hp": 100, "mp": 50, "items": 3})
	
	# Use auto_free for proper cleanup
	for entity in deserialized_entities:
		auto_free(entity)
	

func test_empty_query_serialization():
	# Add entities but query for non-existent component
	var entity = Entity.new()
	entity.add_component(C_SerializationTest.new())
	world.add_entity(entity)
	
	# Query for component that doesn't exist
	var query = world.query.with_all([C_ComplexSerializationTest])
	var serialized_data = ECS.serialize(query)
	
	# Should return empty entities array
	assert_that(serialized_data.entities).has_size(0)

func test_deserialize_nonexistent_file():
	var entities = ECS.deserialize("res://reports/nonexistent_file.tres")
	assert_that(entities).has_size(0)

func test_deserialize_invalid_resource():
	# Create file with invalid resource content
	var file_path = "res://reports/test_invalid.tres"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string("invalid resource content")
	file.close()
	
	var entities = ECS.deserialize(file_path)
	assert_that(entities).has_size(0)

func test_deserialize_empty_resource():
	# Create a GecsData resource with empty entities array
	var empty_data = GecsData.new([])
	var file_path = "res://reports/test_empty_resource.tres"
	ECS.save(empty_data, file_path)
	
	var entities = ECS.deserialize(file_path)
	assert_that(entities).has_size(0)

func test_multiple_entities_with_persistent_components():
	# Create multiple entities with persistent components
	var entities_to_create = []
	for i in range(5):
		var entity = Entity.new()
		entity.name = "PersistentEntity_" + str(i)
		entity.add_component(C_Persistent.new("Player" + str(i), i + 1, 100.0 - i * 5, Vector2(i * 10, i * 20), ["item" + str(i)]))
		entities_to_create.append(entity)
	
	world.add_entities(entities_to_create)
	
	# Serialize all persistent entities
	var query = world.query.with_all([C_Persistent])
	var serialized_data = ECS.serialize(query)
	
	# Save and reload
	var file_path = "res://reports/test_multiple_persistent.tres"
	ECS.save(serialized_data, file_path)
	
	var deserialized_entities = ECS.deserialize(file_path)
	assert_that(deserialized_entities).has_size(5)
	
	# Validate each entity
	for i in range(5):
		var entity = deserialized_entities[i]
		assert_that(entity.name).is_equal("PersistentEntity_" + str(i))
		assert_that(entity.has_component(C_Persistent)).is_true()
		
		var persistent_comp = entity.get_component(C_Persistent)
		assert_that(persistent_comp.player_name).is_equal("Player" + str(i))
		assert_that(persistent_comp.level).is_equal(i + 1)
		assert_that(persistent_comp.health).is_equal(100.0 - i * 5)
		assert_that(persistent_comp.position).is_equal(Vector2(i * 10, i * 20))
		assert_that(persistent_comp.inventory).is_equal(["item" + str(i)])
	
	# Use auto_free for cleanup
	for entity in deserialized_entities:
		auto_free(entity)

func test_performance_serialization_large_dataset():
	# Create many entities for performance testing
	var start_time = Time.get_ticks_msec()
	var entities_to_create = []
	
	for i in range(100):
		var entity = Entity.new()
		entity.name = "PerfEntity_" + str(i)
		entity.add_component(C_SerializationTest.new(i, i * 1.1, "entity_" + str(i), i % 2 == 0))
		entity.add_component(C_Persistent.new("Player" + str(i), i, 100.0, Vector2(i, i)))
		entities_to_create.append(entity)
	
	world.add_entities(entities_to_create)
	
	var creation_time = Time.get_ticks_msec() - start_time
	
	# Serialize all entities
	var serialize_start = Time.get_ticks_msec()
	var query = world.query.with_all([C_SerializationTest])
	var serialized_data = ECS.serialize(query)
	var serialize_time = Time.get_ticks_msec() - serialize_start
	
	# Validate serialization completed
	assert_that(serialized_data.entities).has_size(100)
	
	# Save to file
	var save_start = Time.get_ticks_msec()
	var file_path = "res://reports/test_performance.tres"
	ECS.save(serialized_data, file_path)
	var save_time = Time.get_ticks_msec() - save_start
	
	# Deserialize
	var deserialize_start = Time.get_ticks_msec()
	var deserialized_entities = ECS.deserialize(file_path)
	var deserialize_time = Time.get_ticks_msec() - deserialize_start
	
	# Validate deserialization
	assert_that(deserialized_entities).has_size(100)
	
	# Performance assertions (should complete in reasonable time)
	print("Performance Test Results:")
	print("  Entity Creation: ", creation_time, "ms")
	print("  Serialization: ", serialize_time, "ms")
	print("  File Save: ", save_time, "ms")
	print("  Deserialization: ", deserialize_time, "ms")
	
	# These are reasonable expectations for 100 entities
	assert_that(serialize_time).is_less(1000) # < 1 second
	assert_that(deserialize_time).is_less(1000) # < 1 second
	
	# Use auto_free for cleanup
	for entity in deserialized_entities:
		auto_free(entity)

func test_binary_format_and_auto_detection():
	# Create test entity with various component types
	var entity = Entity.new()
	entity.name = "BinaryTestEntity"
	entity.add_component(C_SerializationTest.new(777, 3.14159, "binary_test", true, Vector2(10.0, 20.0), Vector3(1.0, 2.0, 3.0), Color.RED))
	entity.add_component(C_Persistent.new("BinaryPlayer", 99, 88.8, Vector2(100.0, 200.0), ["sword", "shield", "potion"]))
	
	world.add_entity(entity)
	
	# Serialize the entity
	var query = world.query.with_all([C_SerializationTest])
	var serialized_data = ECS.serialize(query)
	
	# Save in both formats
	var text_path = "res://reports/test_binary_format.tres"
	var binary_test_path = "res://reports/test_binary_format.tres" # Same path for both
	
	# Save as text format
	ECS.save(serialized_data, text_path, false)
	
	# Save as binary format (should create .res file)
	ECS.save(serialized_data, binary_test_path, true)
	
	# Verify both files exist
	assert_that(ResourceLoader.exists("res://reports/test_binary_format.tres")).is_true()
	assert_that(ResourceLoader.exists("res://reports/test_binary_format.res")).is_true()
	
	# Test auto-detection: should load binary (.res) first
	print("Deserializing from: ", binary_test_path)
	print("Binary file exists: ", ResourceLoader.exists("res://reports/test_binary_format.res"))
	print("Text file exists: ", ResourceLoader.exists("res://reports/test_binary_format.tres"))
	
	var entities_auto = ECS.deserialize(binary_test_path)
	print("Deserialized entities count: ", entities_auto.size())
	assert_that(entities_auto).has_size(1)
	
	# Verify loaded data is correct
	var loaded_entity = entities_auto[0]
	assert_that(loaded_entity.name).is_equal("BinaryTestEntity")
	
	var loaded_serialization = loaded_entity.get_component(C_SerializationTest)
	assert_that(loaded_serialization.int_value).is_equal(777)
	assert_that(loaded_serialization.string_value).is_equal("binary_test")
	
	var loaded_persistent = loaded_entity.get_component(C_Persistent)
	assert_that(loaded_persistent.player_name).is_equal("BinaryPlayer")
	assert_that(loaded_persistent.level).is_equal(99)
	assert_that(loaded_persistent.inventory).is_equal(["sword", "shield", "potion"])
	
	# Use auto_free for cleanup
	for _entity in entities_auto:
		auto_free(_entity)
	
	print("Binary format test completed successfully!")
	
	# Compare file sizes (for information)
	var text_file = FileAccess.open("res://reports/test_binary_format.tres", FileAccess.READ)
	var binary_file = FileAccess.open("res://reports/test_binary_format.res", FileAccess.READ)
	
	if text_file and binary_file:
		var text_size = text_file.get_length()
		var binary_size = binary_file.get_length()
		text_file.close()
		binary_file.close()
		
		print("File size comparison:")
		print("  Text (.tres): ", text_size, " bytes")
		print("  Binary (.res): ", binary_size, " bytes")
		print("  Compression: ", "%.1f" % ((1.0 - float(binary_size) / float(text_size)) * 100), "% smaller")
