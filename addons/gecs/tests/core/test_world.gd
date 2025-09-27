extends GdUnitTestSuite  # Assuming GutTest is the correct base class in your setup

var runner: GdUnitSceneRunner
var world: World

const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const C_TestD = preload("res://addons/gecs/tests/components/c_test_d.gd")
const C_TestE = preload("res://addons/gecs/tests/components/c_test_e.gd")
const C_TestF = preload("res://addons/gecs/tests/components/c_test_f.gd")
const C_TestG = preload("res://addons/gecs/tests/components/c_test_g.gd")
const C_TestH = preload("res://addons/gecs/tests/components/c_test_h.gd")

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

func test_add_entity_with_components():
	const val1 = 57
	const val2 = 999
	const val3 = 333

	var entity = Entity.new()
	entity.add_component(C_TestA.new(val1)) # test component's property value with export annotation
	entity.add_component(C_TestF.new(val2)) # test component's property value with no export annotation
	entity.add_component(C_TestG.new(val3)) # test _init() calling count
	# entity.add_component(C_TestH.new(val1)) # this line will lead to crash (the _init parameters has no default value)

	world.add_entities([entity])

	assert_int(entity.get_component(C_TestA).value).is_equal(val1)
	assert_int(entity.get_component(C_TestF).value).is_equal(val2)
	assert_int(C_TestG.init_count).is_equal(1)
	assert_int(C_TestF.init_count).is_equal(1)
