extends GdUnitTestSuite


var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


func test_system_processes_entities_with_required_components():
	# Create entities with the required components
	var entity_a = TestA.new()
	entity_a.add_component(C_TestA.new())

	var entity_b = TestB.new()
	entity_b.add_component(C_TestB.new())

	var entity_c = TestC.new()
	entity_c.add_component(C_TestC.new())

	var entity_d = Entity.new()
	entity_d.add_component(C_TestD.new())

	# Add  some entities before systems
	world.add_entities([entity_a, entity_b])

	world.add_system(TestASystem.new())
	world.add_system(TestBSystem.new())
	world.add_system(TestCSystem.new())

	# add some entities after systems
	world.add_entities([entity_c, entity_d])

	# Run the systems once
	world.process(0.1)

	# Check the values of the components
	assert_int(entity_a.get_component(C_TestA).value).is_equal(1)
	assert_int(entity_b.get_component(C_TestB).value).is_equal(1)
	assert_int(entity_c.get_component(C_TestC).value).is_equal(1)

	# Doesn't get incremented because no systems picked it up
	assert_int(entity_d.get_component(C_TestD).points).is_equal(0)

	# override the component with a new one
	entity_a.add_component(C_TestA.new())
	# Run the systems again
	world.process(0.1)

	# Check the values of the components
	assert_int(entity_a.get_component(C_TestA).value).is_equal(1) # This is one because we added a new component which replaced the old one
	assert_int(entity_b.get_component(C_TestB).value).is_equal(2)
	assert_int(entity_c.get_component(C_TestC).value).is_equal(2)

	# Doesn't get incremented because no systems picked it up (still)
	assert_int(entity_d.get_component(C_TestD).points).is_equal(0)


# FIXME: This test is failing system groups are not being set correctly (or they're being overidden somewhere)
func test_system_group_processes_entities_with_required_components():
	# Create entities with the required components
	var entity_a = TestA.new()
	entity_a.add_component(C_TestA.new())

	var entity_b = TestB.new()
	entity_b.add_component(C_TestB.new())

	var entity_c = TestC.new()
	entity_c.add_component(C_TestC.new())

	var entity_d = Entity.new()
	entity_d.add_component(C_TestD.new())

	# Add  some entities before systems
	world.add_entities([entity_a, entity_b])

	var sys_a = TestASystem.new()
	sys_a.group = "group1"
	var sys_b = TestBSystem.new()
	sys_b.group = "group1"
	var sys_c = TestCSystem.new()
	sys_c.group = "group2"

	world.add_systems([sys_a, sys_b, sys_c])

	# add some entities after systems
	world.add_entities([entity_c, entity_d])

	# Run the systems once by group
	world.process(0.1, "group1")
	world.process(0.1, "group2")

	# Check the values of the components
	assert_int(entity_a.get_component(C_TestA).value).is_equal(1)
	assert_int(entity_b.get_component(C_TestB).value).is_equal(1)
	assert_int(entity_c.get_component(C_TestC).value).is_equal(1)

	# Doesn't get incremented because no systems picked it up
	assert_int(entity_d.get_component(C_TestD).points).is_equal(0)

	# override the component with a new one
	entity_a.add_component(C_TestA.new())
	# Run ALL the systems again (omitting the group means run the default group)
	world.process(0.1)

	# Check the values of the components
	assert_int(entity_a.get_component(C_TestA).value).is_equal(0) # This is one because we added a new component which replaced the old one
	assert_int(entity_b.get_component(C_TestB).value).is_equal(1)
	assert_int(entity_c.get_component(C_TestC).value).is_equal(1)

	# Doesn't get incremented because no systems picked it up (still)
	assert_int(entity_d.get_component(C_TestD).points).is_equal(0)
