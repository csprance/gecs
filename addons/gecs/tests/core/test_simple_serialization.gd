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

func test_serialize_basic_entity():
	# Create a simple entity with one component
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(C_SerializationTest.new())
	
	world.add_entity(entity)
	
	# Serialize the entity
	var query = world.query.with_all([C_SerializationTest])
	var serialized_data = ECS.serialize(query)
	
	# Basic validation
	assert_that(serialized_data).is_not_null()
	assert_that(serialized_data.version).is_equal("0.2")
	assert_that(serialized_data.entities).has_size(1)
	
	print("Serialized data: ", JSON.stringify(serialized_data, "\t"))

func test_save_and_load_simple():
	# Create a simple entity
	var entity = Entity.new()
	entity.name = "SaveLoadTest"
	entity.add_component(C_SerializationTest.new(123, 4.56, "save_load_test", false))
	
	world.add_entity(entity)
	
	# Serialize and save
	var query = world.query.with_all([C_SerializationTest])
	var serialized_data = ECS.serialize(query)
	
	var file_path = "res://reports/test_simple.tres"
	ECS.save(serialized_data, file_path)
	
	# Load and deserialize
	var deserialized_entities = ECS.deserialize(file_path)
	
	# Validate
	assert_that(deserialized_entities).has_size(1)
	var des_entity = deserialized_entities[0]
	assert_that(des_entity.name).is_equal("SaveLoadTest")
	
	# Use auto_free for cleanup
	for _entity in deserialized_entities:
		auto_free(_entity)
	
	# Keep file for inspection in reports directory
