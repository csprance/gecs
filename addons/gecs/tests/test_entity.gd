extends GutTest

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")


func test_add_and_get_component():
	var entity = Entity.new()
	var comp = C_TestA.new()
	entity.add_component(comp)
	# Test that the component was added
	assert_true(entity.has_component(C_TestA.resource_path), "Entity should have the added component.")
	# Test retrieving the component
	var retrieved_component = entity.get_component(C_TestA)
	assert_eq(type_string(typeof(retrieved_component)), type_string(typeof(comp)), "Retrieved component should match the added component.")

func test_remove_component():
	var entity = Entity.new()
	var comp = C_TestB.new()
	entity.add_component(comp)
	entity.remove_component(C_TestB)
	# Test that the component was removed
	assert_false(entity.has_component(comp.resource_path), "Entity should not have the component after removal.")
