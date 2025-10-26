extends GdUnitTestSuite

const TestSystemWithRelationship = preload("res://addons/gecs/tests/systems/s_test_with_relationship.gd")
const TestSystemWithoutRelationship = preload("res://addons/gecs/tests/systems/s_test_without_relationship.gd")
const TestSystemWithGroup = preload("res://addons/gecs/tests/systems/s_test_with_group.gd")
const TestSystemWithoutGroup = preload("res://addons/gecs/tests/systems/s_test_without_group.gd")
const TestSystemNonexistentGroup = preload("res://addons/gecs/tests/systems/s_test_nonexistent_group.gd")

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


func test_system_with_relationship_query():
	# Test the bug: with_relationship and without_relationship returning same results in system query
	var entity_with_rel = Entity.new()
	var entity_without_rel = Entity.new()
	var target = Entity.new()

	# Only entity_with_rel has a relationship
	entity_with_rel.add_relationship(Relationship.new(C_TestA.new(), target))

	world.add_entity(entity_with_rel)
	world.add_entity(entity_without_rel)
	world.add_entity(target)

	var system_with = TestSystemWithRelationship.new()
	world.add_system(system_with)

	# Process the system
	world.process(0.1)

	# System should only find entity_with_rel
	assert_array(system_with.entities_found).has_size(1)
	assert_bool(system_with.entities_found.has(entity_with_rel)).is_true()
	assert_bool(system_with.entities_found.has(entity_without_rel)).is_false()
	assert_bool(system_with.entities_found.has(target)).is_false()


func test_system_without_relationship_query():
	# Test without_relationship in system context
	var entity_with_rel = Entity.new()
	var entity_without_rel = Entity.new()
	var target = Entity.new()

	# Only entity_with_rel has a relationship
	entity_with_rel.add_relationship(Relationship.new(C_TestA.new(), target))

	world.add_entity(entity_with_rel)
	world.add_entity(entity_without_rel)
	world.add_entity(target)

	var system_without = TestSystemWithoutRelationship.new()
	world.add_system(system_without)

	# Process the system
	world.process(0.1)

	# System should find entity_without_rel and target (not entity_with_rel)
	assert_bool(system_without.entities_found.has(entity_with_rel)).is_false()
	assert_bool(system_without.entities_found.has(entity_without_rel)).is_true()
	assert_bool(system_without.entities_found.has(target)).is_true()


func test_system_with_vs_without_relationship_different_results():
	# Verify that with_relationship and without_relationship return DIFFERENT results
	var entity_with_rel = Entity.new()
	var entity_without_rel = Entity.new()
	var target = Entity.new()

	entity_with_rel.add_relationship(Relationship.new(C_TestA.new(), target))

	world.add_entity(entity_with_rel)
	world.add_entity(entity_without_rel)
	world.add_entity(target)

	var system_with = TestSystemWithRelationship.new()
	var system_without = TestSystemWithoutRelationship.new()
	world.add_system(system_with)
	world.add_system(system_without)

	# Process both systems
	world.process(0.1)

	# The two systems should find DIFFERENT entities
	assert_bool(system_with.entities_found.has(entity_with_rel)).is_true()
	assert_bool(system_without.entities_found.has(entity_with_rel)).is_false()

	assert_bool(system_with.entities_found.has(entity_without_rel)).is_false()
	assert_bool(system_without.entities_found.has(entity_without_rel)).is_true()


func test_system_with_group_query():
	# Test with_group in system context
	var entity_in_group = Entity.new()
	var entity_not_in_group = Entity.new()

	entity_in_group.add_to_group("TestGroup")

	world.add_entity(entity_in_group)
	world.add_entity(entity_not_in_group)

	var system = TestSystemWithGroup.new()
	world.add_system(system)

	# Process the system
	world.process(0.1)

	# System should only find entity_in_group
	assert_array(system.entities_found).has_size(1)
	assert_bool(system.entities_found.has(entity_in_group)).is_true()
	assert_bool(system.entities_found.has(entity_not_in_group)).is_false()


func test_system_without_group_query():
	# Test without_group in system context
	var entity_in_group = Entity.new()
	var entity_not_in_group = Entity.new()

	entity_in_group.add_to_group("TestGroup")

	world.add_entity(entity_in_group)
	world.add_entity(entity_not_in_group)

	var system = TestSystemWithoutGroup.new()
	world.add_system(system)

	# Process the system
	world.process(0.1)

	# System should only find entity_not_in_group
	assert_array(system.entities_found).has_size(1)
	assert_bool(system.entities_found.has(entity_not_in_group)).is_true()
	assert_bool(system.entities_found.has(entity_in_group)).is_false()


func test_system_nonexistent_group_query():
	# Test the bug: querying for nonexistent group should return ZERO entities, not all
	var entity1 = Entity.new()
	var entity2 = Entity.new()
	var entity3 = Entity.new()

	entity1.add_to_group("GroupA")
	entity2.add_to_group("GroupB")
	# entity3 has no groups

	world.add_entity(entity1)
	world.add_entity(entity2)
	world.add_entity(entity3)

	var system = TestSystemNonexistentGroup.new()
	world.add_system(system)

	# Process the system
	world.process(0.1)

	# System should find ZERO entities (not all of them!)
	assert_array(system.entities_found).has_size(0)
	assert_bool(system.entities_found.has(entity1)).is_false()
	assert_bool(system.entities_found.has(entity2)).is_false()
	assert_bool(system.entities_found.has(entity3)).is_false()
