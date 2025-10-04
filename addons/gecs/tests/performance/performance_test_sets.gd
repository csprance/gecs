## Performance tests for Array operations in GECS
## Tests the optimized ArrayExtensions methods that are critical for query performance
class_name PerformanceTestSets
extends PerformanceTestBase

var test_arrays: Array[Array] = []
var test_sets: Set = Set.new()

func before_test():
	super.before_test()
	test_arrays.clear()
	test_sets.clear()


func after_test():
	test_arrays.clear()
	test_sets.clear()


func after():
	# Save results
	save_performance_results("res://reports/set_performance_results.json")
	
## Create test arrays with various sizes and overlap characteristics
func create_test_arrays(size1: int, size2: int, overlap_percent: float = 0.5):
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


func is_equal(collection1:Set, collection2:Array) -> bool:
	if collection1.size() != collection2.size():
		return false
	for value in collection1.values():
		if not collection2.has(value):
			return false
	for value in collection2:
		if not collection1.has(value):
			return false
	return true


func test_set_intersect_operations():
	var arrays = create_test_arrays(MEDIUM_SCALE, MEDIUM_SCALE, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var arr_result = ArrayExtensions.intersect(array1, array2)
	var set_result = set1.intersect(set2)
	assert_that(is_equal(set_result, arr_result)).is_true()
	assert_that(set_result.is_equal(Set.new(arr_result))).is_true()


func test_set_union_operations():
	var arrays = create_test_arrays(MEDIUM_SCALE, MEDIUM_SCALE, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var arr_result = ArrayExtensions.union(array1, array2)
	var set_result = set1.union(set2)
	assert_that(is_equal(set_result, arr_result)).is_true()
	assert_that(set_result.is_equal(Set.new(arr_result))).is_true()


func test_set_diff_operations():
	var arrays = create_test_arrays(MEDIUM_SCALE, MEDIUM_SCALE, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var arr_result = ArrayExtensions.difference(array1, array2)
	var set_result = set1.difference(set2)
	assert_that(is_equal(set_result, arr_result)).is_true()
	assert_that(set_result.is_equal(Set.new(arr_result))).is_true()


## Test intersection performance with small arrays
func test_set_intersect_performance_small_scale():
	var arrays = create_test_arrays(SMALL_SCALE, SMALL_SCALE, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var arr_intersect_test = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_greater(0)
	
	var set_intersect_test = func():
		var result = set1.intersect(set2)
		assert_that(result.size()).is_greater(0)

	benchmark("Array_Intersect_Small_Scale", arr_intersect_test)
	benchmark("Set_Intersect_Small_Scale", set_intersect_test)
	print_performance_results()


func test_set_intersect_performance_medium_scale():
	var arrays = create_test_arrays(MEDIUM_SCALE * 10, MEDIUM_SCALE * 10, 0.4)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var arr_intersect_test = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_greater(0)
	
	var set_intersect_test = func():
		var result = set1.intersect(set2)
		assert_that(result.size()).is_greater(0)

	benchmark("Array_Intersect_Medium_Scale", arr_intersect_test)
	benchmark("Set_Intersect_Medium_Scale", set_intersect_test)
	print_performance_results()


func test_set_intersect_performance_large_scale():
	var arrays = create_test_arrays(LARGE_SCALE * 100, LARGE_SCALE * 100, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var intersect_test = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_greater_equal(0)

	var set_intersect_test = func():
		var result = set1.intersect(set2)
		assert_that(result.size()).is_greater(0)

	benchmark("Array_Intersect_Large_Scale", intersect_test)
	benchmark("Set_Intersect_Large_Scale", set_intersect_test)
	print_performance_results()


## Test union performance
func test_set_union_performance():
	var arrays = create_test_arrays(MEDIUM_SCALE * 10, MEDIUM_SCALE * 10, 0.4)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var union_test = func():
		var result = ArrayExtensions.union(array1, array2)
		assert_that(result.size()).is_greater(array1.size())
	
	var set_union_test = func():
		var result = set1.union(set2)
		assert_that(result.size()).is_greater(array1.size())

	benchmark("Array_Union_Performance", union_test)
	benchmark("Set_Union_Performance", set_union_test)
	print_performance_results()


## Test difference performance
func test_set_difference_performance():
	var arrays = create_test_arrays(MEDIUM_SCALE * 10, MEDIUM_SCALE * 10, 0.6)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var difference_test = func():
		var result = ArrayExtensions.difference(array1, array2)
		assert_that(result.size()).is_greater_equal(0)
	
	var set_difference_test = func():
		var result = set1.difference(set2)
		assert_that(result.size()).is_greater_equal(0)

	benchmark("Array_Difference_Performance", difference_test)
	benchmark("Set_Difference_Performance", set_difference_test)
	print_performance_results()

func test_set_remove_performance():
	var arrays = create_test_arrays(LARGE_SCALE*2, LARGE_SCALE*2, 0.6)
	var array1 = arrays[0]
	var array2 = arrays[1]
	var set1 = Set.new(array1)
	var set2 = Set.new(array2)

	var remove_test = func():
		var arr = array1.duplicate()
		var count = 0
		for item in array2:
			if item in arr:
				arr.erase(item)
				count += 1
		print("Array_Remove_Count: ", count)
	
	var set_remove_test = func():
		var _set = set1.duplicate()
		var count = 0
		for item in set2.values():
			if _set.has(item):
				_set.erase(item)
				count += 1
		print("Set_Remove_Count: ", count)

	benchmark("Array_Remove_Performance", remove_test)
	benchmark("Set_Remove_Performance", set_remove_test)
	print_performance_results()
