## Set and Array Performance Tests
## Tests Set operations and ArrayExtensions performance
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


## Helper to create test arrays with specified overlap
func create_test_arrays(size1: int, size2: int, overlap_percent: float = 0.5) -> Array:
	var array1: Array = []
	var array2: Array = []

	# Create first array
	for i in size1:
		array1.append("Entity_%d" % i)

	# Create second array with specified overlap
	var overlap_count = int(size2 * overlap_percent)
	var unique_count = size2 - overlap_count

	# Add overlapping elements
	for i in overlap_count:
		if i < size1:
			array2.append(array1[i])

	# Add unique elements
	for i in unique_count:
		array2.append("Entity_%d" % (size1 + i))

	return [array1, array2]


## Test Set.intersect() performance
func test_set_intersect(scale: int, test_parameters := [[100], [1000], [10000]]):
	var arrays = create_test_arrays(scale, scale, 0.5)
	var set1 = Set.new(arrays[0])
	var set2 = Set.new(arrays[1])

	var time_ms = PerfHelpers.time_it(func():
		var result = set1.intersect(set2)
	)

	PerfHelpers.record_result("set_intersect", scale, time_ms)


## Test Set.union() performance
func test_set_union(scale: int, test_parameters := [[100], [1000], [10000]]):
	var arrays = create_test_arrays(scale, scale, 0.5)
	var set1 = Set.new(arrays[0])
	var set2 = Set.new(arrays[1])

	var time_ms = PerfHelpers.time_it(func():
		var result = set1.union(set2)
	)

	PerfHelpers.record_result("set_union", scale, time_ms)


## Test Set.difference() performance
func test_set_difference(scale: int, test_parameters := [[100], [1000], [10000]]):
	var arrays = create_test_arrays(scale, scale, 0.5)
	var set1 = Set.new(arrays[0])
	var set2 = Set.new(arrays[1])

	var time_ms = PerfHelpers.time_it(func():
		var result = set1.difference(set2)
	)

	PerfHelpers.record_result("set_difference", scale, time_ms)


## Test ArrayExtensions.intersect() performance
func test_array_intersect(scale: int, test_parameters := [[100], [1000], [10000]]):
	var arrays = create_test_arrays(scale, scale, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var time_ms = PerfHelpers.time_it(func():
		var result = ArrayExtensions.intersect(array1, array2)
	)

	PerfHelpers.record_result("array_intersect", scale, time_ms)


## Test ArrayExtensions.union() performance
func test_array_union(scale: int, test_parameters := [[100], [1000], [10000]]):
	var arrays = create_test_arrays(scale, scale, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var time_ms = PerfHelpers.time_it(func():
		var result = ArrayExtensions.union(array1, array2)
	)

	PerfHelpers.record_result("array_union", scale, time_ms)


## Test ArrayExtensions.difference() performance
func test_array_difference(scale: int, test_parameters := [[100], [1000], [10000]]):
	var arrays = create_test_arrays(scale, scale, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var time_ms = PerfHelpers.time_it(func():
		var result = ArrayExtensions.difference(array1, array2)
	)

	PerfHelpers.record_result("array_difference", scale, time_ms)


## Test Set.erase() performance
func test_set_erase(scale: int, test_parameters := [[100], [1000], [10000]]):
	var array1: Array = []
	for i in scale:
		array1.append("Entity_%d" % i)

	var test_set := Set.new(array1)

	var time_ms = PerfHelpers.time_it(func():
		# erase half the elements
		for i in scale / 2:
			test_set.erase("Entity_%d" % i)
	)

	PerfHelpers.record_result("set_erase", scale, time_ms)


## Test Set vs Array operations with no overlap
func test_set_vs_array_no_overlap(scale: int, test_parameters := [[100], [1000]]):
	var arrays = create_test_arrays(scale, scale, 0.0) # No overlap
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	# Test array intersect
	var array_time = PerfHelpers.time_it(func():
		var result = ArrayExtensions.intersect(array1, array2)
	)

	# Test set intersect
	var set_time = PerfHelpers.time_it(func():
		var result = set1.intersect(set2)
	)

	PerfHelpers.record_result("array_intersect_no_overlap", scale, array_time)
	PerfHelpers.record_result("set_intersect_no_overlap", scale, set_time)


## Test Set vs Array operations with complete overlap
func test_set_vs_array_complete_overlap(scale: int, test_parameters := [[100], [1000]]):
	var arrays = create_test_arrays(scale, scale, 1.0) # Complete overlap
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	# Test array intersect
	var array_time = PerfHelpers.time_it(func():
		var result = ArrayExtensions.intersect(array1, array2)
	)

	# Test set intersect
	var set_time = PerfHelpers.time_it(func():
		var result = set1.intersect(set2)
	)

	PerfHelpers.record_result("array_intersect_complete_overlap", scale, array_time)
	PerfHelpers.record_result("set_intersect_complete_overlap", scale, set_time)
