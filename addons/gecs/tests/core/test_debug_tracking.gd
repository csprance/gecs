extends GdUnitTestSuite

# Test suite for System debug tracking (lastRunData)

var world: World

func before_test():
	world = World.new()
	world.name = "TestWorld"
	Engine.get_main_loop().root.add_child(world)
	ECS.world = world
	# Enable debug mode for these tests
	ECS.debug = true

func after_test():
	ECS.world = null
	if is_instance_valid(world):
		world.queue_free()

func test_debug_tracking_process_mode():
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


func test_debug_tracking_process_all_mode():
	# Create entities
	for i in range(15):
		var entity = Entity.new()
		entity.add_component(C_DebugTrackingTestB.new())
		world.add_entity(entity)

	# Create system with PROCESS_ALL execution method
	var system = ProcessAllSystem.new()
	world.add_system(system)

	# Process once
	world.process(0.016)

	# Verify debug data
	assert_that(system.lastRunData["entity_count"]).is_equal(15)
	assert_that(system.lastRunData["execution_time_ms"]).is_greater(0.0)

	# Verify no accumulation across frames
	var times = []
	for i in range(5):
		world.process(0.016)
		times.append(system.lastRunData["execution_time_ms"])

	# All times should be relatively similar (not growing)
	var avg_time = times.reduce(func(acc, val): return acc + val, 0.0) / times.size()
	for time in times:
		# Each time should be within 2x of average (generous margin)
		assert_that(time).is_less(avg_time * 2.0)

	print("ProcessAll times across 5 frames: %s" % [times])


func test_debug_tracking_process_batch_mode():
	# Create entities with different component combinations (multiple archetypes)
	for i in range(10):
		var entity = Entity.new()
		entity.add_component(C_DebugTrackingTestA.new())
		world.add_entity(entity)

	for i in range(5):
		var entity = Entity.new()
		entity.add_component(C_DebugTrackingTestA.new())
		entity.add_component(C_DebugTrackingTestB.new())
		world.add_entity(entity)

	# Create system with PROCESS_BATCH execution method
	var system = ProcessBatchSystem.new()
	world.add_system(system)

	# Process once
	world.process(0.016)

	# Verify debug data
	assert_that(system.lastRunData["entity_count"]).is_equal(15)
	assert_that(system.lastRunData["archetype_count"]).is_greater_equal(2)
	assert_that(system.lastRunData["execution_time_ms"]).is_greater(0.0)

	print("Batch mode: %d entities across %d archetypes in %.3f ms" % [
		system.lastRunData["entity_count"],
		system.lastRunData["archetype_count"],
		system.lastRunData["execution_time_ms"]
	])


func test_debug_tracking_subsystems():
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


func test_execution_time_not_accumulating():
	# This is the key test for the issue mentioned
	# Create entities
	for i in range(20):
		var entity = Entity.new()
		entity.add_component(C_DebugTrackingTestA.new())
		world.add_entity(entity)

	var system = ProcessSystem.new()
	world.add_system(system)

	# Run 10 frames and collect timing data
	var times = []
	for frame in range(10):
		world.process(0.016)
		times.append(system.lastRunData["execution_time_ms"])
		print("Frame %d: %.6f ms" % [frame, system.lastRunData["execution_time_ms"]])

	# Calculate statistics
	var min_time = times.min()
	var max_time = times.max()
	var avg_time = times.reduce(func(acc, val): return acc + val, 0.0) / times.size()

	print("\nTiming statistics:")
	print("  Min: %.6f ms" % min_time)
	print("  Max: %.6f ms" % max_time)
	print("  Avg: %.6f ms" % avg_time)

	# If time was accumulating, frame 9 would be ~10x frame 0
	# Instead, all times should be within same order of magnitude
	var last_time = times[times.size() - 1]
	var first_time = times[0]

	# Times should be within 3x of each other (very generous margin)
	# If accumulating, last would be 10x first
	assert_that(last_time).is_less(first_time * 3.0)
	assert_that(max_time).is_less(avg_time * 2.0)


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
