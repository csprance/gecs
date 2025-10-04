extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)
	
func test_observer_receive_component_changed():
	world.add_system(TestASystem.new())
	var test_a_observer = TestAObserver.new()
	world.add_observer(test_a_observer)
	
	# Create entities with the required components
	var entity_a = TestA.new()
	entity_a.name = "a"
	entity_a.add_component(C_TestA.new())

	var entity_b = TestB.new()
	entity_b.name = "b"
	entity_b.add_component(C_TestA.new())
	entity_b.add_component(C_TestB.new())
	
	# issue #43
	var entity_a2 = TestA.new()
	entity_a2.name = "a"
	entity_a2.add_component(C_TestA.new())
	world.get_node(world.entity_nodes_root).add_child(entity_a2)
	world.add_entity(entity_a2, null, false)
	assert_int(test_a_observer.added_count).is_equal(1)
	

	# Add  some entities before systems
	world.add_entities([entity_a, entity_b])
	assert_int(test_a_observer.added_count).is_equal(3)
	

	# Run the systems once
	print('process 1st')
	world.process(0.1)

	# Check the event_count
	assert_int(test_a_observer.event_count).is_equal(2)
	
	# Run the systems again
	print('process 2nd')
	world.process(0.1)

	# Check the event_count
	assert_int(test_a_observer.event_count).is_equal(4)
