extends GdUnitTestSuite

const CommandBuffer = preload("res://addons/gecs/ecs/command_buffer.gd")

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Write performance result to JSONL file
func _write_perf_result(test_name: String, scale: int, time_ms: float) -> void:
	var dir_path = "reports/perf"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file_path = dir_path + "/command_buffer_" + test_name + ".jsonl"
	var file = FileAccess.open(file_path, FileAccess.WRITE_READ)
	if file:
		file.seek_end()
		var result = {
			"timestamp": Time.get_datetime_string_from_system(),
			"test": test_name,
			"scale": scale,
			"time_ms": time_ms,
			"godot_version": Engine.get_version_info()["string"]
		}
		file.store_line(JSON.stringify(result))
		file.close()


## Test bulk entity removal with backwards iteration (OLD WAY)
func test_bulk_removal_backwards(scale: int, test_parameters := [[100], [1000], [10000]]) -> void:
	# Create entities
	var entities: Array[Entity] = []
	for i in scale:
		var entity = TestA.new()
		world.add_entity(entity)
		entities.append(entity)

	var start_time := Time.get_ticks_usec()

	# OLD WAY: Backwards iteration
	for i in range(entities.size() - 1, -1, -1):
		world.remove_entity(entities[i])

	var end_time := Time.get_ticks_usec()
	var time_ms := (end_time - start_time) / 1000.0

	_write_perf_result("bulk_removal_backwards", scale, time_ms)

	# Cleanup
	for entity in entities:
		if is_instance_valid(entity):
			entity.free()


## Test bulk entity removal with CommandBuffer (NEW WAY)
func test_bulk_removal_command_buffer(scale: int, test_parameters := [[100], [1000], [10000]]) -> void:
	# Create entities
	var entities: Array[Entity] = []
	for i in scale:
		var entity = TestA.new()
		world.add_entity(entity)
		entities.append(entity)

	var cmd = CommandBuffer.new(world)
	var start_time := Time.get_ticks_usec()

	# NEW WAY: Forward iteration with CommandBuffer
	for entity in entities:
		cmd.remove_entity(entity)

	cmd.execute()

	var end_time := Time.get_ticks_usec()
	var time_ms := (end_time - start_time) / 1000.0

	_write_perf_result("bulk_removal_command_buffer", scale, time_ms)

	# Cleanup
	for entity in entities:
		if is_instance_valid(entity):
			entity.free()


## Test bulk component additions with individual calls (OLD WAY)
func test_bulk_component_add_individual(scale: int, test_parameters := [[100], [1000], [10000]]) -> void:
	# Create entities
	var entities: Array[Entity] = []
	for i in scale:
		var entity = TestA.new()
		world.add_entity(entity)
		entities.append(entity)

	var start_time := Time.get_ticks_usec()

	# OLD WAY: Individual add_component calls
	for entity in entities:
		entity.add_component(C_TestB.new())

	var end_time := Time.get_ticks_usec()
	var time_ms := (end_time - start_time) / 1000.0

	_write_perf_result("bulk_component_add_individual", scale, time_ms)


## Test bulk component additions with CommandBuffer (NEW WAY)
func test_bulk_component_add_command_buffer(scale: int, test_parameters := [[100], [1000], [10000]]) -> void:
	# Create entities
	var entities: Array[Entity] = []
	for i in scale:
		var entity = TestA.new()
		world.add_entity(entity)
		entities.append(entity)

	var cmd = CommandBuffer.new(world)
	var start_time := Time.get_ticks_usec()

	# NEW WAY: CommandBuffer batching
	for entity in entities:
		cmd.add_component(entity, C_TestB.new())

	cmd.execute()

	var end_time := Time.get_ticks_usec()
	var time_ms := (end_time - start_time) / 1000.0

	_write_perf_result("bulk_component_add_command_buffer", scale, time_ms)


## Test state transitions (remove + add) with individual calls (OLD WAY)
func test_state_transition_individual(scale: int, test_parameters := [[100], [1000], [10000]]) -> void:
	# Create entities with initial state
	var entities: Array[Entity] = []
	for i in scale:
		var entity = TestA.new()
		entity.add_component(C_TestB.new())
		world.add_entity(entity)
		entities.append(entity)

	var start_time := Time.get_ticks_usec()

	# OLD WAY: Two archetype moves per entity
	for entity in entities:
		entity.remove_component(C_TestB)
		entity.add_component(C_TestC.new())

	var end_time := Time.get_ticks_usec()
	var time_ms := (end_time - start_time) / 1000.0

	_write_perf_result("state_transition_individual", scale, time_ms)


## Test state transitions with CommandBuffer (NEW WAY)
func test_state_transition_command_buffer(scale: int, test_parameters := [[100], [1000], [10000]]) -> void:
	# Create entities with initial state
	var entities: Array[Entity] = []
	for i in scale:
		var entity = TestA.new()
		entity.add_component(C_TestB.new())
		world.add_entity(entity)
		entities.append(entity)

	var cmd = CommandBuffer.new(world)
	var start_time := Time.get_ticks_usec()

	# NEW WAY: Batched - one archetype move per entity
	for entity in entities:
		cmd.remove_component(entity, C_TestB)
		cmd.add_component(entity, C_TestC.new())

	cmd.execute()

	var end_time := Time.get_ticks_usec()
	var time_ms := (end_time - start_time) / 1000.0

	_write_perf_result("state_transition_command_buffer", scale, time_ms)


## Test cache invalidation count (verify optimization)
func test_cache_invalidation_optimization(scale: int, test_parameters := [[100], [1000], [10000]]) -> void:
	# Create entities
	var entities: Array[Entity] = []
	for i in scale:
		var entity = TestA.new()
		world.add_entity(entity)
		entities.append(entity)

	var cmd = CommandBuffer.new(world)
	var initial_invalidations = world._cache_invalidation_count

	# Queue many operations
	for entity in entities:
		cmd.add_component(entity, C_TestB.new())

	cmd.execute()

	var invalidations_delta = world._cache_invalidation_count - initial_invalidations

	# Should only invalidate once despite many operations
	assert_int(invalidations_delta).is_equal(1)

	_write_perf_result("cache_invalidations", scale, float(invalidations_delta))
