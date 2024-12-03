extends GdUnitTestSuite


const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")

func test_component_key_is_set_correctly():
	# Create an instance of a concrete Component subclass
	var component = C_TestA.new()
	# The key should be set to the resource path of the component's script
	var expected_key = component.get_script().resource_path
	assert_str("res://addons/gecs/tests/components/c_test_a.gd").is_equal(expected_key)

func test_components_match():
	# Create two instances of the same concrete Component subclass
	var component_a = C_TestA.new()
	var component_b = C_TestA.new()
	var component_c = C_TestB.new()
	var component_d = C_TestB.new()
	component_d.value = 2
	
	# The components should match
	assert_bool(component_a.equals(component_b)).is_true()
	# should not match because the type is different
	assert_bool(component_a.equals(component_c)).is_false()
	# Should not match because the value is different
	assert_bool(component_c.equals(component_d)).is_false()
