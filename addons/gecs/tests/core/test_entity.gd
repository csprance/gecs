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


# TODO: We need to add the world here becuase remove fails because we don't have access to world


func test_add_and_get_component():
	var entity = auto_free(TestA.new())
	var comp = C_TestA.new()
	entity.add_component(comp)
	# Test that the component was added
	assert_bool(entity.has_component(C_TestA)).is_true()
	# Test retrieving the component
	var retrieved_component = entity.get_component(C_TestA)
	assert_str(type_string(typeof(retrieved_component))).is_equal(type_string(typeof(comp)))

# Components need default values on init or they will error
# FIXME: How can we catch this in the code?
func test_add_entity_with_component_with_no_defaults_in_init():
	var entity = auto_free(Entity.new())
	# this line will lead to crash (the _init parameters has no default value)
	assert_error(func(): entity.add_component(C_TestH.new(57)))

func test_add_multiple_components_and_has():
	var entity = auto_free(TestB.new())
	var comp1 = C_TestA.new()
	var comp2 = C_TestB.new()
	entity.add_components([comp1, comp2])
	# Test that the components were added
	assert_bool(entity.has_component(C_TestA)).is_true()
	assert_bool(entity.has_component(C_TestB)).is_true()
	assert_bool(entity.has_component(C_TestC)).is_false()


func test_remove_component():
	var entity = auto_free(TestB.new())
	var comp = C_TestB.new()
	entity.add_component(comp)
	entity.remove_component(C_TestB)
	# Test that the component was removed
	assert_bool(entity.has_component(C_TestB)).is_false()


func test_add_get_has_relationship():
	var entitya = auto_free(TestC.new())
	var entityb = auto_free(TestC.new())
	var r_testa_entitya = Relationship.new(C_TestA.new(), entitya)
	# Add the relationship
	entityb.add_relationship(r_testa_entitya)
	# Test that the relationship was added
	# With the actual relationship
	assert_bool(entityb.has_relationship(r_testa_entitya)).is_true()
	# with a matching relationship
	assert_bool(entityb.has_relationship(Relationship.new(C_TestA.new(), entitya))).is_true()
	# Test retrieving the relationship
	# with the actual relationship
	var inst_retrieved_relationship = entityb.get_relationship(r_testa_entitya)
	assert_str(type_string(typeof(inst_retrieved_relationship))).is_equal(
		type_string(typeof(r_testa_entitya))
	)
	# with a matching relationship
	var class_retrieved_relationship = entityb.get_relationship(
		Relationship.new(C_TestA.new(), entitya)
	)
	assert_str(type_string(typeof(class_retrieved_relationship))).is_equal(
		type_string(typeof(r_testa_entitya))
	)
	assert_str(type_string(typeof(class_retrieved_relationship))).is_equal(
		type_string(typeof(Relationship.new(C_TestA.new(), entitya)))
	)

func test_add_and_remove_component():
	var entity = auto_free(TestB.new())
	for i in range(99):
		var comp = C_TestB.new()
		entity.add_component(comp)
		entity.remove_component(C_TestB)
		print('_component_path_cache size=', entity._component_path_cache.size())

	# Test memory leak
	assert_int(entity._component_path_cache.size()).is_equal(0)


func test_remove_components_with_scripts():
	var entity = auto_free(TestB.new())
	var comp1 = C_TestA.new()
	var comp2 = C_TestB.new()
	var comp3 = C_TestC.new()

	# Add multiple components
	entity.add_components([comp1, comp2, comp3])

	# Verify all were added
	assert_bool(entity.has_component(C_TestA)).is_true()
	assert_bool(entity.has_component(C_TestB)).is_true()
	assert_bool(entity.has_component(C_TestC)).is_true()

	# Remove multiple components by Script class
	entity.remove_components([C_TestA, C_TestB])

	# Test that the components were removed
	assert_bool(entity.has_component(C_TestA)).is_false()
	assert_bool(entity.has_component(C_TestB)).is_false()
	# Test that C_TestC is still there
	assert_bool(entity.has_component(C_TestC)).is_true()


func test_remove_components_with_instances():
	var entity = auto_free(TestB.new())
	var comp1 = C_TestA.new()
	var comp2 = C_TestB.new()
	var comp3 = C_TestC.new()

	# Add multiple components
	entity.add_components([comp1, comp2, comp3])

	# Verify all were added
	assert_bool(entity.has_component(C_TestA)).is_true()
	assert_bool(entity.has_component(C_TestB)).is_true()
	assert_bool(entity.has_component(C_TestC)).is_true()

	# Remove multiple components by instance
	entity.remove_components([comp1, comp2])

	# Test that the components were removed
	assert_bool(entity.has_component(C_TestA)).is_false()
	assert_bool(entity.has_component(C_TestB)).is_false()
	# Test that C_TestC is still there
	assert_bool(entity.has_component(C_TestC)).is_true()


func test_remove_components_mixed():
	var entity = auto_free(TestB.new())
	var comp1 = C_TestA.new()
	var comp2 = C_TestB.new()
	var comp3 = C_TestC.new()

	# Add multiple components
	entity.add_components([comp1, comp2, comp3])

	# Remove with mixed Script and instance
	entity.remove_components([C_TestA, comp2])

	# Test that the components were removed
	assert_bool(entity.has_component(C_TestA)).is_false()
	assert_bool(entity.has_component(C_TestB)).is_false()
	# Test that C_TestC is still there
	assert_bool(entity.has_component(C_TestC)).is_true()
