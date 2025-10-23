extends GdUnitTestSuite

# Test suite for System debug tracking (lastRunData)

var world: World

func before_test():
	world = World.new()
	world.name = "TestWorld"
	Engine.get_main_loop().root.add_child(world)
	ECS.world = world

func after_test():
	ECS.world = null
	if is_instance_valid(world):
		world.queue_free()

func test_debug_tracking_process_mode():
	# Enable debug mode for these tests
	ECS.debug = true
	# Create entities
	for i in range(10):
		var entity = Entity.new()
		entity.add_component(C_DebugTrackingTestA.new())
		world.add_entity(entity)

	# Create system with PROCESS execution method
	var system = ProcessSystem.new()
	world.add_system(system)

	# Process once
	world.process(0.016)

	# Debug: Print what's in lastRunData
	print("DEBUG: ECS.debug = ", ECS.debug)
	print("DEBUG: lastRunData = ", system.lastRunData)
	print("DEBUG: lastRunData keys = ", system.lastRunData.keys())

	# Verify debug data
	assert_that(system.lastRunData.has("system_name")).is_true()
	assert_that(system.lastRunData.has("frame_delta")).is_true()
	assert_that(system.lastRunData.has("entity_count")).is_true()
	assert_that(system.lastRunData.has("execution_time_ms")).is_true()

	# Verify values
	assert_that(system.lastRunData["frame_delta"]).is_equal(0.016)
	assert_that(system.lastRunData["entity_count"]).is_equal(10)
	assert_that(system.lastRunData["execution_time_ms"]).is_greater(0.0)
	assert_that(system.lastRunData["parallel"]).is_equal(false)

	# Store first execution time
	var first_exec_time = system.lastRunData["execution_time_ms"]

	# Process again
	world.process(0.032)

	# Verify time is different (not accumulating)
	var second_exec_time = system.lastRunData["execution_time_ms"]
	assert_that(system.lastRunData["frame_delta"]).is_equal(0.032)

	# Times should be similar but not identical (and definitely not accumulated)
	# If accumulating, second would be ~2x first
	assert_that(second_exec_time).is_less(first_exec_time * 1.5)
	print("First exec: %.3f ms, Second exec: %.3f ms" % [first_exec_time, second_exec_time])


func test_debug_tracking_subsystems():
	# Enable debug mode for these tests
	ECS.debug = true
	# Create entities
	for i in range(10):
		var entity = Entity.new()
		entity.add_component(C_DebugTrackingTestA.new())
		entity.add_component(C_DebugTrackingTestB.new())
		world.add_entity(entity)

	# Create system with SUBSYSTEMS execution method
	var system = SubsystemsTestSystem.new()
	world.add_system(system)

	# Process once
	world.process(0.016)

	# Verify debug data
	assert_that(system.lastRunData["execution_time_ms"]).is_greater(0.0)

	# Verify subsystem data
	assert_that(system.lastRunData.has(0)).is_true()
	assert_that(system.lastRunData.has(1)).is_true()

	# First subsystem
	assert_that(system.lastRunData[0]["entity_count"]).is_equal(10)

	# Second subsystem
	assert_that(system.lastRunData[1]["entity_count"]).is_equal(10)

	print("Subsystem 0: %s" % [system.lastRunData[0]])
	print("Subsystem 1: %s" % [system.lastRunData[1]])


func test_debug_disabled_has_no_data():
	# Disable debug mode
	ECS.debug = false

	# Create entities
	for i in range(5):
		var entity = Entity.new()
		entity.add_component(C_DebugTrackingTestA.new())
		world.add_entity(entity)

	# Create system
	var system = ProcessSystem.new()
	world.add_system(system)

	# Process
	world.process(0.016)

	# lastRunData should be empty or not updated when debug is off
	# (It might still exist from a previous run, but shouldn't be updated)
	var initial_data = system.lastRunData.duplicate()

	# Process again
	world.process(0.016)

	# Data should not change (because ECS.debug = false)
	assert_that(system.lastRunData).is_equal(initial_data)

	print("With ECS.debug=false, lastRunData remains unchanged: %s" % [system.lastRunData])


# Test system - PROCESS mode
class ProcessSystem extends System:
	func query() -> QueryBuilder:
		return ECS.world.query.with_all([C_DebugTrackingTestA])

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		for entity in entities:
			var comp = entity.get_component(C_DebugTrackingTestA)
			comp.value += delta

# Test system - unified process
class ProcessAllSystem extends System:
	func query() -> QueryBuilder:
		return ECS.world.query.with_all([C_DebugTrackingTestB])

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		for entity in entities:
			var comp = entity.get_component(C_DebugTrackingTestB)
			comp.count += 1

# Test system - batch processing with iterate
class ProcessBatchSystem extends System:
	func query() -> QueryBuilder:
		return ECS.world.query.with_all([C_DebugTrackingTestA]).iterate([C_DebugTrackingTestA])

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		var test_a_components = components[0]
		for i in range(entities.size()):
			test_a_components[i].value += delta

# Test system - SUBSYSTEMS mode
class SubsystemsTestSystem extends System:
	func sub_systems() -> Array[Array]:
		return [
			[ECS.world.query.with_all([C_DebugTrackingTestA]), process_sub],
			[ECS.world.query.with_all([C_DebugTrackingTestB]).iterate([C_DebugTrackingTestB]), batch_sub]
		]

	func process_sub(entities: Array[Entity], components: Array, delta: float) -> void:
		for entity in entities:
			var comp = entity.get_component(C_DebugTrackingTestA)
			comp.value += delta

	func batch_sub(entities: Array[Entity], components: Array, delta: float) -> void:
		if components.size() > 0 and components[0].size() > 0:
			var test_b_components = components[0]
			for i in range(entities.size()):
				test_b_components[i].count += 1
