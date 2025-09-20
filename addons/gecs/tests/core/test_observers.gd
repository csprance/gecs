extends GdUnitTestSuite

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

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)
	
func test_observer_receive_component_changed():
	# Create entities with the required components
	var entity_a = TestA.new()
	entity_a.name = "a"
	entity_a.add_component(C_TestA.new())

	var entity_b = TestB.new()
	entity_b.name = "b"
	entity_b.add_component(C_TestA.new())
	entity_b.add_component(C_TestB.new())

	

	# Add  some entities before systems
	world.add_entities([entity_a, entity_b])

	world.add_system(TestSystemA.new())
	#world.add_system(TestSystemB.new())
	#world.add_system(TestSystemC.new())
	var test_a_observer = TestAObserver.new()
	world.add_observer(test_a_observer)

	# Run the systems once
	print('process 1st')
	world.process(0.1)

	# Check the event_count
	assert_int(test_a_observer.event_count).is_equal(1)
	
	# Run the systems again
	print('process 2nd')
	world.process(0.1)

	# Check the event_count
	assert_int(test_a_observer.event_count).is_equal(2)
	
