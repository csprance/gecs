## Component Indexing Performance Tests
## Compares performance of using Script objects vs String paths as dictionary keys
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	if world:
		world.purge(false)


## Test dictionary lookup performance with String keys (current implementation)
func test_string_key_lookup(scale: int, test_parameters := [[1000], [10000], [100000]]):
	# Create string-based dictionary
	var string_dict: Dictionary = {}

	# Populate with component paths
	var component_types = [C_TestA, C_TestB, C_TestC, C_TestD]
	for comp_type in component_types:
		var path = comp_type.resource_path
		string_dict[path] = []
		for i in scale / 4:
			string_dict[path].append(i)

	# Time lookups
	var time_ms = PerfHelpers.time_it(func():
		for i in 10000:  # Many lookups
			var comp_type = component_types[i % 4]
			var _result = string_dict.get(comp_type.resource_path, [])
	)

	PerfHelpers.record_result("string_key_lookup", scale, time_ms)


## Test dictionary lookup performance with Script object keys
func test_script_key_lookup(scale: int, test_parameters := [[1000], [10000], [100000]]):
	# Create script-based dictionary
	var script_dict: Dictionary = {}

	# Populate with component scripts directly
	var component_types = [C_TestA, C_TestB, C_TestC, C_TestD]
	for comp_type in component_types:
		script_dict[comp_type] = []
		for i in scale / 4:
			script_dict[comp_type].append(i)

	# Time lookups
	var time_ms = PerfHelpers.time_it(func():
		for i in 10000:  # Many lookups
			var comp_type = component_types[i % 4]
			var _result = script_dict.get(comp_type, [])
	)

	PerfHelpers.record_result("script_key_lookup", scale, time_ms)


## Test dictionary insertion performance with String keys
func test_string_key_insertion(scale: int, test_parameters := [[1000], [10000], [100000]]):
	var component_types = [C_TestA, C_TestB, C_TestC, C_TestD]

	var time_ms = PerfHelpers.time_it(func():
		var string_dict: Dictionary = {}
		for i in scale:
			var comp_type = component_types[i % 4]
			var path = comp_type.resource_path
			if not string_dict.has(path):
				string_dict[path] = []
			string_dict[path].append(i)
	)

	PerfHelpers.record_result("string_key_insertion", scale, time_ms)


## Test dictionary insertion performance with Script object keys
func test_script_key_insertion(scale: int, test_parameters := [[1000], [10000], [100000]]):
	var component_types = [C_TestA, C_TestB, C_TestC, C_TestD]

	var time_ms = PerfHelpers.time_it(func():
		var script_dict: Dictionary = {}
		for i in scale:
			var comp_type = component_types[i % 4]
			if not script_dict.has(comp_type):
				script_dict[comp_type] = []
			script_dict[comp_type].append(i)
	)

	PerfHelpers.record_result("script_key_insertion", scale, time_ms)


## Test hash computation overhead - String path generation
func test_get_resource_path_overhead(scale: int, test_parameters := [[10000], [100000], [1000000]]):
	var component_types = [C_TestA, C_TestB, C_TestC, C_TestD]

	var time_ms = PerfHelpers.time_it(func():
		for i in scale:
			var comp_type = component_types[i % 4]
			var _path = comp_type.resource_path
	)

	PerfHelpers.record_result("get_resource_path_overhead", scale, time_ms)


## Test dictionary lookup performance with Integer keys
func test_integer_key_lookup(scale: int, test_parameters := [[1000], [10000], [100000]]):
	# Create integer-based dictionary
	var int_dict: Dictionary = {}

	# Populate with integer keys (simulating instance IDs or hashes)
	var component_types = [C_TestA, C_TestB, C_TestC, C_TestD]
	for i in range(4):
		int_dict[i] = []
		for j in scale / 4:
			int_dict[i].append(j)

	# Time lookups
	var time_ms = PerfHelpers.time_it(func():
		for i in 10000:  # Many lookups
			var key = i % 4
			var _result = int_dict.get(key, [])
	)

	PerfHelpers.record_result("integer_key_lookup", scale, time_ms)


## Test dictionary insertion performance with Integer keys
func test_integer_key_insertion(scale: int, test_parameters := [[1000], [10000], [100000]]):
	var time_ms = PerfHelpers.time_it(func():
		var int_dict: Dictionary = {}
		for i in scale:
			var key = i % 4
			if not int_dict.has(key):
				int_dict[key] = []
			int_dict[key].append(i)
	)

	PerfHelpers.record_result("integer_key_insertion", scale, time_ms)


## Test Script.get_instance_id() overhead
func test_get_instance_id_overhead(scale: int, test_parameters := [[10000], [100000], [1000000]]):
	var component_types = [C_TestA, C_TestB, C_TestC, C_TestD]

	var time_ms = PerfHelpers.time_it(func():
		for i in scale:
			var comp_type = component_types[i % 4]
			var _id = comp_type.get_instance_id()
	)

	PerfHelpers.record_result("get_instance_id_overhead", scale, time_ms)


## Test realistic query performance with String keys (current implementation)
func test_realistic_query_with_strings(scale: int, test_parameters := [[100], [1000], [10000]]):
	# Setup entities
	for i in scale:
		var entity = Entity.new()
		entity.name = "Entity_%d" % i
		if i % 2 == 0:
			entity.add_component(C_TestA.new())
		if i % 3 == 0:
			entity.add_component(C_TestB.new())
		world.add_entity(entity, null, false)

	# Time queries (current string-based approach)
	var time_ms = PerfHelpers.time_it(func():
		for i in 100:  # Execute query 100 times
			var _entities = world.query.with_all([C_TestA]).execute()
	)

	PerfHelpers.record_result("realistic_query_with_strings", scale, time_ms)
	world.purge(false)
