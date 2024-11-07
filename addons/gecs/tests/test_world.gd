extends GutTest  # Assuming GutTest is the correct base class in your setup

func test_add_and_remove_entity():
	var world = World.new()
	var entity = Entity.new()
	world.add_entity(entity)
	assert_true(world.entities.has(entity), "Entity should be added to the world.")
	world.remove_entity(entity)
	assert_false(world.entities.has(entity), "Entity should be removed from the world.")
