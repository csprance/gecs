extends GdUnitTestSuite  # Assuming GutTest is the correct base class in your setup

var runner : GdUnitSceneRunner
var world: World

const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const C_TestD = preload("res://addons/gecs/tests/components/c_test_d.gd")
const C_TestE = preload("res://addons/gecs/tests/components/c_test_e.gd")

const TestSystemA = preload("res://addons/gecs/tests/systems/s_test_a.gd")
const TestSystemB = preload("res://addons/gecs/tests/systems/s_test_b.gd")
const TestSystemC = preload("res://addons/gecs/tests/systems/s_test_c.gd")

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

func test_export_world():
	# Create two entities and add a test component to each.
	# Assume C_TestA and C_TestB are components whose value/points are incremented by TestSystemA and TestSystemB respectively.
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	
	var compA = C_TestA.new()
	var compB = C_TestB.new()
	entity1.add_component(compA)
	entity2.add_component(compB)
	
	# Add an extra component on entity1 and set its value to a crazy number.
	var compE = C_TestE.new()
	compE.value = 1234567  # Crazy value.
	entity1.add_component(compE)
	
	world.add_entities([entity1, entity2])
	
	# Add systems that update the component values
	var sysA = TestSystemA.new()
	var sysB = TestSystemB.new()
	world.add_systems([sysA, sysB])
	
	# Run systems once (simulate one frame)
	world.process(0.1)
	
	# Capture updated values from the components
	var valueA_after = entity1.get_component(C_TestA).value
	var valueB_after = entity2.get_component(C_TestB).value
	var crazy_value = entity1.get_component(C_TestE).value
	
	# Export the world state
	var export_path = "user://temp_world.ecs"
	world.export_world(export_path)
	
	# Create a new world instance and import the saved state
	world.import_world(export_path)
	
	# Assert that we have restored 2 entities
	assert_int(world.entities.size()).is_equal(2)
	
	# Run systems again on the new world
	world.process(0.1)
	
	var new_valueA = world.entities[0].get_component(C_TestA).value
	var new_valueB = world.entities[1].get_component(C_TestB).value
	var new_crazy_value = world.entities[0].get_component(C_TestE).value
	
	# Expect the component values to have been incremented once more
	assert_int(new_valueA).is_equal(valueA_after + 1)
	assert_int(new_valueB).is_equal(valueB_after + 1)
	# Verify that the crazy value remains unchanged
	assert_int(new_crazy_value).is_equal(crazy_value)
