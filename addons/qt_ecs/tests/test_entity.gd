extends GutTest

func test_add_and_get_component():
	var entity = Entity.new()
	var velocity_component = Velocity.new()
	entity.add_component(velocity_component)
	# Test that the component was added
	assert_true(entity.has_component(Velocity.resource_path), "Entity should have the added component.")
	# Test retrieving the component
	var retrieved_component = entity.get_component(Velocity)
	assert_eq(type_string(typeof(retrieved_component)), type_string(typeof(velocity_component)), "Retrieved component should match the added component.")

func test_remove_component():
	var entity = Entity.new()
	var velocity_component = Velocity.new()
	entity.add_component(velocity_component)
	entity.remove_component(Velocity)
	# Test that the component was removed
	assert_false(entity.has_component(velocity_component.resource_path), "Entity should not have the component after removal.")
