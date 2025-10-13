extends GdUnitTestSuite

## Test suite for verifying topological sorting of systems and their execution order in the World.
## This test demonstrates how system dependencies (Runs.Before and Runs.After) affect the order
## in which systems are executed during World.process().
##
## NOTE: Inner classes prevent GdUnit from discovering tests, so all test components/systems
## have been extracted to separate files in addons/gecs/tests/systems/

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


func test_topological_sort_basic_execution_order():
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)

	# Add systems in random order (NOT dependency order)
	var sys_d = S_TestOrderD.new()
	var sys_b = S_TestOrderB.new()
	var sys_c = S_TestOrderC.new()
	var sys_a = S_TestOrderA.new()

	# Add in intentionally wrong order but topo sort enabled
	world.add_systems([sys_d, sys_b, sys_c, sys_a], true)

	# Verify the systems are now sorted correctly
	var sorted_systems = world.systems_by_group[""]
	assert_int(sorted_systems.size()).is_equal(4)
	assert_object(sorted_systems[0]).is_same(sys_a) # A runs first
	assert_object(sorted_systems[1]).is_same(sys_b) # B runs after A
	assert_object(sorted_systems[2]).is_same(sys_c) # C runs after B
	assert_object(sorted_systems[3]).is_same(sys_d) # D runs last

	# Process the world - systems should execute in dependency order
	world.process(0.016)
	
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent

	# Verify execution order in the log
	assert_array(comp.execution_log).is_equal(["A", "B", "C", "D"])

	# Verify value accumulation happened in correct order
	# A adds 1, B adds 10, C adds 100, D adds 1000 = 1111
	assert_int(comp.value).is_equal(1111)


func test_topological_sort_multiple_groups():
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)

	# Create systems for different groups
	var sys_a_physics = S_TestOrderA.new()
	sys_a_physics.group = "physics"

	var sys_b_physics = S_TestOrderB.new()
	sys_b_physics.group = "physics"

	var sys_a_render = S_TestOrderA.new()
	sys_a_render.group = "render"

	var sys_c_render = S_TestOrderC.new()
	sys_c_render.group = "render"

	# Add in wrong order
	world.add_systems([sys_b_physics, sys_a_physics, sys_c_render, sys_a_render], true)

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

	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	# Process only physics group
	comp.execution_log.clear()
	world.process(0.016, "physics")
	assert_array(comp.execution_log).is_equal(["A", "B"])

	# Process only render group
	comp.execution_log.clear()
	world.process(0.016, "render")
	assert_array(comp.execution_log).is_equal(["A", "C"])


func test_topological_sort_no_dependencies():
	# Systems with no dependencies should maintain their addition order
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)

	var sys_x = S_TestOrderX.new()
	var sys_y = S_TestOrderY.new()
	var sys_z = S_TestOrderZ.new()

	# Add in specific order
	world.add_systems([sys_x, sys_y, sys_z], true)

	# When systems have no dependencies, they maintain addition order
	var sorted_systems = world.systems_by_group[""]
	assert_int(sorted_systems.size()).is_equal(3)
	# Order should be preserved since no dependencies exist
	assert_object(sorted_systems[0]).is_same(sys_x)
	assert_object(sorted_systems[1]).is_same(sys_y)
	assert_object(sorted_systems[2]).is_same(sys_z)

	world.process(0.016)
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	assert_array(comp.execution_log).is_equal(["X", "Y", "Z"])


func test_topological_sort_with_add_system_flag():
	# Test that add_system with topo_sort=true automatically sorts
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)

	# Add systems in wrong order but with topo_sort enabled
	world.add_system(S_TestOrderD.new(), true)
	world.add_system(S_TestOrderB.new(), true)
	world.add_system(S_TestOrderC.new(), true)
	world.add_system(S_TestOrderA.new(), true)

	# Systems should already be sorted
	var sorted_systems = world.systems_by_group[""]
	assert_bool(sorted_systems[0] is S_TestOrderA).is_true()
	assert_bool(sorted_systems[1] is S_TestOrderB).is_true()
	assert_bool(sorted_systems[2] is S_TestOrderC).is_true()
	assert_bool(sorted_systems[3] is S_TestOrderD).is_true()

	# Verify execution order
	world.process(0.016)
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	assert_array(comp.execution_log).is_equal(["A", "B", "C", "D"])


func test_topological_sort_complex_dependencies():
	# Test more complex dependency graph
	var entity = Entity.new()
	entity.name = "TestEntity"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)

	# Create systems and check their dependencies before adding
	var sys_e = S_TestOrderE.new()
	var sys_f = S_TestOrderF.new()
	var sys_g = S_TestOrderG.new()
	var sys_h = S_TestOrderH.new()

	# Debug: Check if systems have dependency metadata
	print("System E dependencies: ", sys_e.deps())
	print("System F dependencies: ", sys_f.deps())
	print("System G dependencies: ", sys_g.deps())
	print("System H dependencies: ", sys_h.deps())

	# Check if systems have the proper class names for dependency resolution
	print("System E class: ", sys_e.get_script().get_global_name())
	print("System F class: ", sys_f.get_script().get_global_name())
	print("System G class: ", sys_g.get_script().get_global_name())
	print("System H class: ", sys_h.get_script().get_global_name())

	print("Adding systems with topo_sort=true...")
	# Add in random order
	world.add_systems([sys_f, sys_h, sys_g, sys_e], true)

	# Debug: Check system order after sorting
	var sorted_systems = world.systems_by_group[""]
	print("Systems after sorting (count: ", sorted_systems.size(), "):")
	for i in range(sorted_systems.size()):
		var sys = sorted_systems[i]
		print("  [", i, "]: ", sys.get_script().get_global_name(), " (same as original? E:", sys == sys_e, " F:", sys == sys_f, " G:", sys == sys_g, " H:", sys == sys_h, ")")

	# Verify if the sort actually happened by checking if order changed
	var original_order = [sys_f, sys_h, sys_g, sys_e]
	var order_changed = false
	for i in range(sorted_systems.size()):
		if sorted_systems[i] != original_order[i]:
			order_changed = true
			break
	print("Order changed after sorting: ", order_changed)

	world.process(0.016)

	# E must run first, F and G must run after E, H must run after both F and G
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	var log = comp.execution_log

	# Debug: Check execution
	print("Raw execution log: ", log)
	print("Log size: ", log.size())
	
	if log.is_empty():
		print("ERROR: No systems executed! Log is empty.")
		print("Entity has component: ", entity.has_component(C_TestOrderComponent))
		print("Component value: ", comp.value)
		assert_bool(false).is_true() # Force test failure with debug info
		return

	# Simple verification without processing - just check the raw log
	print("Expected order should be: E first, H last, F and G in middle")
	
	# Verify the correct execution order
	assert_int(log.size()).is_equal(4)
	
	# E must run first (no dependencies)
	assert_str(log[0]).is_equal("E")
	
	# H must run last (depends on both F and G)
	assert_str(log[3]).is_equal("H")
	
	# F and G must run after E but before H (they can be in any order)
	var middle_systems = [log[1], log[2]]
	assert_bool(middle_systems.has("F")).is_true()
	assert_bool(middle_systems.has("G")).is_true()
	
	print("Topological sort is working correctly!")


func test_topological_sort_partial_dependencies():
	"""Test with only some systems having dependencies (E, F, G only)"""
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity_Partial"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)
	
	# Add systems: E (no deps), F (depends on E), G (depends on E)
	world.add_system(S_TestOrderE.new(), true) # Enable topo_sort
	world.add_system(S_TestOrderF.new(), true)
	world.add_system(S_TestOrderG.new(), true)
	
	world.process(0.016)
	
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	var log = comp.execution_log
	
	print("Partial dependencies test - Log: ", log)
	
	# Should be: E first, then F and G (in any order)
	assert_int(log.size()).is_equal(3)
	assert_str(log[0]).is_equal("E")
	
	var middle_systems = [log[1], log[2]]
	assert_bool(middle_systems.has("F")).is_true()
	assert_bool(middle_systems.has("G")).is_true()


func test_topological_sort_linear_chain():
	"""Test a linear dependency chain: A->B, B->C, C->D"""
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity_Linear"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)
	
	# Add systems in reverse order to test sorting
	world.add_system(S_TestOrderD.new(), true) # D depends on C - Enable topo_sort
	world.add_system(S_TestOrderC.new(), true) # C depends on B
	world.add_system(S_TestOrderB.new(), true) # B depends on A
	world.add_system(S_TestOrderA.new(), true) # A has no deps
	
	world.process(0.016)
	
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	var log = comp.execution_log
	
	print("Linear chain test - Log: ", log)
	
	# Should be exactly: A, B, C, D
	assert_int(log.size()).is_equal(4)
	assert_str(log[0]).is_equal("A")
	assert_str(log[1]).is_equal("B")
	assert_str(log[2]).is_equal("C")
	assert_str(log[3]).is_equal("D")


func test_topological_sort_no_dependencies_order_preserved():
	"""Test systems with wildcard dependencies - A should run before E"""
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity_NoDeps"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)
	
	# Add systems with no dependencies
	world.add_system(S_TestOrderE.new(), true) # No deps - Enable topo_sort
	world.add_system(S_TestOrderA.new(), true) # No deps
	
	world.process(0.016)
	
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	var log = comp.execution_log
	
	print("No dependencies test - Log: ", log)
	
	# Should execute in dependency order: A runs before all (wildcard), then E
	assert_int(log.size()).is_equal(2)
	assert_str(log[0]).is_equal("A") # A runs first (has Runs.Before: [ECS.wildcard])
	assert_str(log[1]).is_equal("E") # E runs after A


func test_topological_sort_mixed_scenarios():
	"""Test all systems together with complex interdependencies"""
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity_Mixed"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)
	
	# Add all systems in random order to test sorting
	world.add_system(S_TestOrderH.new(), true) # H depends on F,G - Enable topo_sort
	world.add_system(S_TestOrderB.new(), true) # B depends on A
	world.add_system(S_TestOrderF.new(), true) # F depends on E
	world.add_system(S_TestOrderD.new(), true) # D depends on C
	world.add_system(S_TestOrderE.new(), true) # E has no deps
	world.add_system(S_TestOrderA.new(), true) # A has no deps
	world.add_system(S_TestOrderG.new(), true) # G depends on E
	world.add_system(S_TestOrderC.new(), true) # C depends on B
	
	world.process(0.016)
	
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	var log = comp.execution_log
	
	print("Mixed scenarios test - Log: ", log)
	print("Expected constraints:")
	print("  - Chain A->B->C->D must be in order")
	print("  - Chain E->F,G->H must be in order")
	print("  - A and E can be in any order (both have no deps)")
	
	assert_int(log.size()).is_equal(8)
	
	# Find positions of each system
	var positions = {}
	for i in range(log.size()):
		positions[log[i]] = i
	
	# Verify chain A->B->C->D
	assert_bool(positions["A"] < positions["B"]).is_true()
	assert_bool(positions["B"] < positions["C"]).is_true()
	assert_bool(positions["C"] < positions["D"]).is_true()
	
	# Verify chain E->F,G->H
	assert_bool(positions["E"] < positions["F"]).is_true()
	assert_bool(positions["E"] < positions["G"]).is_true()
	assert_bool(positions["F"] < positions["H"]).is_true()
	assert_bool(positions["G"] < positions["H"]).is_true()
	
	print("All dependency constraints satisfied!")


func test_no_topological_sort_preserves_order():
	"""Test that when topo_sort=false (default), systems execute in add order"""
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity_NoTopoSort"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)
	
	# Add systems with dependencies but WITHOUT topo_sort enabled
	# This should execute in the order they were added, not dependency order
	world.add_system(S_TestOrderH.new()) # H depends on F,G (topo_sort=false by default)
	world.add_system(S_TestOrderF.new()) # F depends on E
	world.add_system(S_TestOrderE.new()) # E has no deps
	world.add_system(S_TestOrderG.new()) # G depends on E
	
	world.process(0.016)
	
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	var log = comp.execution_log
	
	print("No topo sort test - Log: ", log)
	print("Systems should execute in add order: H, F, E, G")
	
	# Should execute in the exact order they were added, ignoring dependencies
	assert_int(log.size()).is_equal(4)
	assert_str(log[0]).is_equal("H") # First added
	assert_str(log[1]).is_equal("F") # Second added
	assert_str(log[2]).is_equal("E") # Third added
	assert_str(log[3]).is_equal("G") # Fourth added
	
	print("✓ Systems executed in add order, ignoring dependencies (as expected)")


func test_mixed_topological_sort_flags():
	"""Test mixing systems with and without topo_sort enabled"""
	# Create entity with component
	var entity = Entity.new()
	entity.name = "TestEntity_MixedFlags"
	entity.add_component(C_TestOrderComponent.new())
	world.add_entity(entity)
	
	# Add some systems with topo_sort=true, others with false
	world.add_system(S_TestOrderE.new(), true) # E: topo_sort=true
	world.add_system(S_TestOrderH.new(), false) # H: topo_sort=false
	world.add_system(S_TestOrderF.new(), true) # F: topo_sort=true
	world.add_system(S_TestOrderG.new(), false) # G: topo_sort=false
	
	world.process(0.016)
	
	var comp := entity.get_component(C_TestOrderComponent) as C_TestOrderComponent
	var log = comp.execution_log
	
	print("Mixed topo sort flags test - Log: ", log)
	
	# This test documents the current behavior - exact order may depend on implementation
	# The main point is that it should execute without errors
	assert_int(log.size()).is_equal(4)
	
	# All systems should have executed
	assert_bool(log.has("E")).is_true()
	assert_bool(log.has("F")).is_true()
	assert_bool(log.has("G")).is_true()
	assert_bool(log.has("H")).is_true()
	
	print("✓ Mixed topo_sort flags handled without errors")
