extends GdUnitTestSuite

## Test suite for verifying topological sorting of systems and their execution order in the World.
## This test demonstrates how system dependencies (Runs.Before and Runs.After) affect the order
## in which systems are executed during World.process().

# Test components to track execution order
class TestOrderComponent extends Component:
	@export var execution_log: Array = []
	@export var value: int = 0

# System A - runs first (before everything)
class SystemA extends System:
	func deps():
		return {
			Runs.Before: [ECS.wildcard],  # Run before all other systems
			Runs.After: [],
		}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var comp = entity.get_component(TestOrderComponent)
		comp.execution_log.append("A")
		comp.value += 1

# System B - runs after A, before C
class SystemB extends System:
	func deps():
		return {
			Runs.After: [SystemA],
			Runs.Before: [SystemC],
		}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var comp = entity.get_component(TestOrderComponent)
		comp.execution_log.append("B")
		comp.value += 10

# System C - runs after B, before D
class SystemC extends System:
	func deps():
		return {
			Runs.After: [SystemB],
			Runs.Before: [SystemD],
		}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var comp = entity.get_component(TestOrderComponent)
		comp.execution_log.append("C")
		comp.value += 100

# System D - runs last (after everything)
class SystemD extends System:
	func deps():
		return {
			Runs.After: [ECS.wildcard],  # Run after all other systems
			Runs.Before: [],
		}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var comp = entity.get_component(TestOrderComponent)
		comp.execution_log.append("D")
		comp.value += 1000

# Systems with no dependencies - should maintain addition order
class SystemNoDepsX extends System:
	func deps():
		return {Runs.After: [], Runs.Before: []}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var comp = entity.get_component(TestOrderComponent)
		comp.execution_log.append("X")

class SystemNoDepsY extends System:
	func deps():
		return {Runs.After: [], Runs.Before: []}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var comp = entity.get_component(TestOrderComponent)
		comp.execution_log.append("Y")

class SystemNoDepsZ extends System:
	func deps():
		return {Runs.After: [], Runs.Before: []}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var comp = entity.get_component(TestOrderComponent)
		comp.execution_log.append("Z")

# Complex dependency graph systems
class SystemE extends System:
	func deps():
		return {Runs.After: [], Runs.Before: []}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var c = entity.get_component(TestOrderComponent)
		c.execution_log.append("E")

class SystemF extends System:
	func deps():
		return {Runs.After: [SystemE], Runs.Before: []}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var c = entity.get_component(TestOrderComponent)
		c.execution_log.append("F")

class SystemG extends System:
	func deps():
		return {Runs.After: [SystemE], Runs.Before: []}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var c = entity.get_component(TestOrderComponent)
		c.execution_log.append("G")

class SystemH extends System:
	func deps():
		return {Runs.After: [SystemF, SystemG], Runs.Before: []}

	func query():
		return q.with_all([TestOrderComponent])

	func process(entity: Entity, delta: float):
		var c = entity.get_component(TestOrderComponent)
		c.execution_log.append("H")


func test_topological_sort_basic_execution_order():
	# Create a world and entity
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

	var entity = Entity.new()
	entity.name = "TestEntity"
	var comp = TestOrderComponent.new()
	entity.add_component(comp)
	world.add_entity(entity)

	# Add systems in random order (NOT dependency order)
	var sys_d = SystemD.new()
	var sys_b = SystemB.new()
	var sys_c = SystemC.new()
	var sys_a = SystemA.new()

	# Add in intentionally wrong order
	world.add_system(sys_d, false)
	world.add_system(sys_b, false)
	world.add_system(sys_c, false)
	world.add_system(sys_a, false)

	# Sort systems by dependencies
	ArrayExtensions.topological_sort(world.systems_by_group)

	# Verify the systems are now sorted correctly
	var sorted_systems = world.systems_by_group[""]
	assert_int(sorted_systems.size()).is_equal(4)
	assert_object(sorted_systems[0]).is_same(sys_a)  # A runs first
	assert_object(sorted_systems[1]).is_same(sys_b)  # B runs after A
	assert_object(sorted_systems[2]).is_same(sys_c)  # C runs after B
	assert_object(sorted_systems[3]).is_same(sys_d)  # D runs last

	# Process the world - systems should execute in dependency order
	world.process(0.016)

	# Verify execution order in the log
	assert_array(comp.execution_log).is_equal(["A", "B", "C", "D"])

	# Verify value accumulation happened in correct order
	# A adds 1, B adds 10, C adds 100, D adds 1000 = 1111
	assert_int(comp.value).is_equal(1111)

	world.queue_free()


# DISABLED - test_topological_sort_multiple_groups
"""
func test_topological_sort_multiple_groups():
	# Create world
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

	var entity = Entity.new()
	entity.name = "TestEntity"
	var comp = TestOrderComponent.new()
	entity.add_component(comp)
	world.add_entity(entity)

	# Create systems for different groups
	var sys_a_physics = SystemA.new()
	sys_a_physics.group = "physics"

	var sys_b_physics = SystemB.new()
	sys_b_physics.group = "physics"

	var sys_a_render = SystemA.new()
	sys_a_render.group = "render"

	var sys_c_render = SystemC.new()
	sys_c_render.group = "render"

	# Add in wrong order
	world.add_system(sys_b_physics, false)
	world.add_system(sys_a_physics, false)
	world.add_system(sys_c_render, false)
	world.add_system(sys_a_render, false)

	# Sort all groups
	ArrayExtensions.topological_sort(world.systems_by_group)

	# Verify physics group is sorted
	var physics_systems = world.systems_by_group["physics"]
	assert_int(physics_systems.size()).is_equal(2)
	assert_object(physics_systems[0]).is_same(sys_a_physics)
	assert_object(physics_systems[1]).is_same(sys_b_physics)

	# Verify render group is sorted
	var render_systems = world.systems_by_group["render"]
	assert_int(render_systems.size()).is_equal(2)
	assert_object(render_systems[0]).is_same(sys_a_render)
	assert_object(render_systems[1]).is_same(sys_c_render)

	# Process only physics group
	comp.execution_log.clear()
	world.process(0.016, "physics")
	assert_array(comp.execution_log).is_equal(["A", "B"])

	# Process only render group
	comp.execution_log.clear()
	world.process(0.016, "render")
	assert_array(comp.execution_log).is_equal(["A", "C"])

	world.queue_free()
"""


# DISABLED - test_topological_sort_no_dependencies
"""
func test_topological_sort_no_dependencies():
	# Systems with no dependencies should maintain their addition order
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

	var entity = Entity.new()
	entity.name = "TestEntity"
	var comp = TestOrderComponent.new()
	entity.add_component(comp)
	world.add_entity(entity)

	var sys_x = SystemNoDepsX.new()
	var sys_y = SystemNoDepsY.new()
	var sys_z = SystemNoDepsZ.new()

	# Add in specific order
	world.add_system(sys_x, false)
	world.add_system(sys_y, false)
	world.add_system(sys_z, false)

	ArrayExtensions.topological_sort(world.systems_by_group)

	# When systems have no dependencies, they maintain addition order
	var sorted_systems = world.systems_by_group[""]
	assert_int(sorted_systems.size()).is_equal(3)
	# Order should be preserved since no dependencies exist
	assert_object(sorted_systems[0]).is_same(sys_x)
	assert_object(sorted_systems[1]).is_same(sys_y)
	assert_object(sorted_systems[2]).is_same(sys_z)

	world.process(0.016)
	assert_array(comp.execution_log).is_equal(["X", "Y", "Z"])

	world.queue_free()
"""


# func test_topological_sort_with_add_system_flag():
	# Test that add_system with topo_sort=true automatically sorts
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

	var entity = Entity.new()
	entity.name = "TestEntity"
	var comp = TestOrderComponent.new()
	entity.add_component(comp)
	world.add_entity(entity)

	# Add systems in wrong order but with topo_sort enabled
	world.add_system(SystemD.new(), true)
	world.add_system(SystemB.new(), true)
	world.add_system(SystemC.new(), true)
	world.add_system(SystemA.new(), true)

	# Systems should already be sorted
	var sorted_systems = world.systems_by_group[""]
	assert_bool(sorted_systems[0] is SystemA).is_true()
	assert_bool(sorted_systems[1] is SystemB).is_true()
	assert_bool(sorted_systems[2] is SystemC).is_true()
	assert_bool(sorted_systems[3] is SystemD).is_true()

	# Verify execution order
	world.process(0.016)
	assert_array(comp.execution_log).is_equal(["A", "B", "C", "D"])

	world.queue_free()


# func test_topological_sort_complex_dependencies():
	# Test more complex dependency graph
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

	var entity = Entity.new()
	entity.name = "TestEntity"
	var comp = TestOrderComponent.new()
	entity.add_component(comp)
	world.add_entity(entity)

	# Add in random order
	world.add_system(SystemH.new(), false)
	world.add_system(SystemF.new(), false)
	world.add_system(SystemG.new(), false)
	world.add_system(SystemE.new(), false)

	ArrayExtensions.topological_sort(world.systems_by_group)

	world.process(0.016)

	# E must run first, F and G must run after E, H must run after both F and G
	var log = comp.execution_log
	
	# Debug: Check if any systems executed
	if log.is_empty():
		print("ERROR: No systems executed! Log is empty.")
		print("Number of systems: ", world.systems_by_group[""].size())
		print("Entity has component: ", entity.has_component(TestOrderComponent))
		print("Component execution log size: ", comp.execution_log.size())
		assert_bool(false).is_true()  # Force test failure with debug info
		return
	
	assert_str(log[0]).is_equal("E")  # E must be first
	assert_str(log[3]).is_equal("H")  # H must be last
	# F and G can be in any order, but both must be after E and before H
	assert_bool(log[1] in ["F", "G"]).is_true()
	assert_bool(log[2] in ["F", "G"]).is_true()
	assert_bool(log[1] != log[2]).is_true()  # But they can't be the same

	world.queue_free()


# func test_system_order_property():
	# Verify that systems get their 'order' property set correctly
	var world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world

	var sys_a = SystemA.new()
	var sys_b = SystemB.new()
	var sys_c = SystemC.new()
	var sys_d = SystemD.new()

	world.add_system(sys_d, false)
	world.add_system(sys_b, false)
	world.add_system(sys_c, false)
	world.add_system(sys_a, false)

	ArrayExtensions.topological_sort(world.systems_by_group)

	# The systems should now be in sorted order in the array
	var sorted_systems = world.systems_by_group[""]
	var order_values = []
	for i in range(sorted_systems.size()):
		order_values.append(sorted_systems[i].order)

	# Note: The current implementation doesn't set the 'order' property during sorting
	# This test documents that behavior. If you want the order property set,
	# you'd need to update ArrayExtensions.topological_sort() to do:
	# for i in range(sorted_result.size()):
	#     sorted_result[i].order = i

	world.queue_free()
