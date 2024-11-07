extends "res://addons/gut/test.gd"
const path = "res://game/components/velocity.gd"


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
	assert_eq(path, expected_key, "Component key should be set to the script's resource path.")
