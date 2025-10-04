extends GdUnitTestSuite  # Assuming GutTest is the correct base class in your setup

var runner: GdUnitSceneRunner
var world: World




func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


func test_add_and_remove_entity():
	var entity = Entity.new()
	# Test adding
	world.add_entities([entity])
	assert_bool(world.entities.has(entity)).is_true()
	# Test removing
	world.remove_entity(entity)
	assert_bool(world.entities.has(entity)).is_false()


func test_add_and_remove_system():
	var system = System.new()
	# Test adding
	world.add_systems([system])
	assert_bool(world.systems.has(system)).is_true()
	# Test removing
	world.remove_system(system)
	assert_bool(world.systems.has(system)).is_false()


func test_purge():
	# Add an entity and a system
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	world.add_entities([entity2, entity1])

	var system1 = System.new()
	var system2 = System.new()
	world.add_systems([system1, system2])

	# PURGE!!!
	world.purge(false)
	# Should be no entities and systems now
	assert_int(world.entities.size()).is_equal(0)
	assert_int(world.systems.size()).is_equal(0)
	
