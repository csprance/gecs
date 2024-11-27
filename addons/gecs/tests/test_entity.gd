extends GdUnitTestSuite

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")

func test_add_and_get_component():
	var entity = TestA.new()
	var comp = C_TestA.new()
	entity.add_component(comp)
	# Test that the component was added
	assert_bool(entity.has_component(C_TestA)).is_true()
	# Test retrieving the component
	var retrieved_component = entity.get_component(C_TestA)
	assert_str(type_string(typeof(retrieved_component))).is_equal(type_string(typeof(comp)))

func test_remove_component():
	var entity = TestB.new()
	var comp = C_TestB.new()
	entity.add_component(comp)
	entity.remove_component(C_TestB)
	# Test that the component was removed
	assert_bool(entity.has_component(comp)).is_false()
