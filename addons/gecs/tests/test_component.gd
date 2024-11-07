extends "res://addons/gut/test.gd"
const path = "res://game/components/velocity.gd"
func test_component_key_is_set_correctly():
	
	# Create an instance of a concrete Component subclass
	var VelocityComponent = preload(path)  # Adjust path as needed
	var component = VelocityComponent.new()
	# The key should be set to the resource path of the component's script
	var expected_key = component.get_script().resource_path
	assert_eq(path, expected_key, "Component key should be set to the script's resource path.")
