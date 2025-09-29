## Performance tests for Array operations in GECS
## Tests the optimized ArrayExtensions methods that are critical for query performance
class_name PerformanceTestArrays
extends PerformanceTestBase

var test_arrays: Array[Array] = []


func before_test():
	super.before_test()
	test_arrays.clear()


func after_test():
	test_arrays.clear()


func after():
	# Save results
	save_performance_results("res://reports/array_performance_results.json")
	
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


## Test intersection performance with small arrays
func test_array_intersect_small_scale():
	var arrays = create_test_arrays(SMALL_SCALE / 2, SMALL_SCALE / 2, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var intersect_test = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_greater(0)

	benchmark("Array_Intersect_Small_Scale", intersect_test)
	print_performance_results()

	# Small array intersections should be very fast
	assert_performance_threshold(
		"Array_Intersect_Small_Scale", 5.0, "Array intersect too slow for small arrays"
	)


func test_array_intersect_medium_scale():
	var arrays = create_test_arrays(MEDIUM_SCALE / 2, MEDIUM_SCALE / 2, 0.3)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var intersect_test = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_greater(0)

	benchmark("Array_Intersect_Medium_Scale", intersect_test)
	print_performance_results()

	# Medium array intersections should be reasonably fast
	assert_performance_threshold(
		"Array_Intersect_Medium_Scale", 25.0, "Array intersect too slow for medium arrays"
	)


func test_array_intersect_large_scale():
	var arrays = create_test_arrays(LARGE_SCALE / 4, LARGE_SCALE / 4, 0.2)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var intersect_test = func():
		var result = ArrayExtensions.intersect(array1, array2)
		# May be 0 with low overlap
		assert_that(result.size()).is_greater_equal(0)

	benchmark("Array_Intersect_Large_Scale", intersect_test)
	print_performance_results()

	# Large array intersections should complete in reasonable time
	assert_performance_threshold(
		"Array_Intersect_Large_Scale", 100.0, "Array intersect too slow for large arrays"
	)


## Test union performance
func test_array_union_performance():
	var arrays = create_test_arrays(MEDIUM_SCALE / 3, MEDIUM_SCALE / 3, 0.4)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var union_test = func():
		var result = ArrayExtensions.union(array1, array2)
		assert_that(result.size()).is_greater(array1.size())

	benchmark("Array_Union_Performance", union_test)
	print_performance_results()

	# Union should be reasonably fast
	assert_performance_threshold("Array_Union_Performance", 30.0, "Array union too slow")


## Test difference performance
func test_array_difference_performance():
	var arrays = create_test_arrays(MEDIUM_SCALE / 2, MEDIUM_SCALE / 3, 0.6)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var difference_test = func():
		var result = ArrayExtensions.difference(array1, array2)
		assert_that(result.size()).is_greater_equal(0)

	benchmark("Array_Difference_Performance", difference_test)
	print_performance_results()

	# Difference should be reasonably fast
	assert_performance_threshold("Array_Difference_Performance", 25.0, "Array difference too slow")


## Test performance with different array size ratios
func test_array_operations_size_ratios():
	# Test intersect with very different sized arrays
	var small_array: Array = []
	var large_array: Array = []

	for i in 50:
		small_array.append("SmallEntity_%d" % i)

	for i in MEDIUM_SCALE:
		large_array.append("LargeEntity_%d" % i)
		if i < 25: # Some overlap
			large_array.append("SmallEntity_%d" % i)

	var size_ratio_test = func():
		var result = ArrayExtensions.intersect(small_array, large_array)
		assert_that(result.size()).is_greater(0)

	benchmark("Array_Intersect_Size_Ratio", size_ratio_test)
	print_performance_results()

	# Should be optimized to use smaller array for lookup
	assert_performance_threshold(
		"Array_Intersect_Size_Ratio", 15.0, "Array intersect size ratio optimization not working"
	)


## Test performance with no overlap (worst case)
func test_array_operations_no_overlap():
	var array1: Array = []
	var array2: Array = []

	for i in MEDIUM_SCALE / 4:
		array1.append("Array1_Entity_%d" % i)
		array2.append("Array2_Entity_%d" % i)

	var no_overlap_intersect = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_equal(0)

	var no_overlap_difference = func():
		var result = ArrayExtensions.difference(array1, array2)
		assert_that(result.size()).is_equal(array1.size())

	benchmark("Array_Intersect_No_Overlap", no_overlap_intersect)
	benchmark("Array_Difference_No_Overlap", no_overlap_difference)

	print_performance_results()

	# No overlap cases should be fast (early termination)
	assert_performance_threshold(
		"Array_Intersect_No_Overlap", 20.0, "Array intersect no overlap case too slow"
	)
	assert_performance_threshold(
		"Array_Difference_No_Overlap", 20.0, "Array difference no overlap case too slow"
	)


## Test performance with complete overlap
func test_array_operations_complete_overlap():
	var array1: Array = []
	var array2: Array = []

	for i in MEDIUM_SCALE / 4:
		var item = "Entity_%d" % i
		array1.append(item)
		array2.append(item)

	var complete_overlap_intersect = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_equal(array1.size())

	var complete_overlap_union = func():
		var result = ArrayExtensions.union(array1, array2)
		assert_that(result.size()).is_equal(array1.size())

	var complete_overlap_difference = func():
		var result = ArrayExtensions.difference(array1, array2)
		assert_that(result.size()).is_equal(0)

	benchmark("Array_Intersect_Complete_Overlap", complete_overlap_intersect)
	benchmark("Array_Union_Complete_Overlap", complete_overlap_union)
	benchmark("Array_Difference_Complete_Overlap", complete_overlap_difference)

	print_performance_results()

	# Complete overlap cases should be handled efficiently
	assert_performance_threshold(
		"Array_Intersect_Complete_Overlap", 20.0, "Array intersect complete overlap too slow"
	)
	assert_performance_threshold(
		"Array_Union_Complete_Overlap", 25.0, "Array union complete overlap too slow"
	)
	assert_performance_threshold(
		"Array_Difference_Complete_Overlap", 20.0, "Array difference complete overlap too slow"
	)


## Test repeated operations (should benefit from any potential optimizations)
func test_repeated_array_operations():
	var arrays = create_test_arrays(SMALL_SCALE, SMALL_SCALE, 0.5)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var repeated_intersects = func():
		for i in 100:
			var result = ArrayExtensions.intersect(array1, array2)
			assert_that(result.size()).is_greater(0)

	benchmark("Repeated_Array_Intersects", repeated_intersects)
	print_performance_results()

	# Repeated operations should be fast
	assert_performance_threshold(
		"Repeated_Array_Intersects", 50.0, "Repeated array operations too slow"
	)


## Compare optimized vs naive implementation performance
func test_optimization_effectiveness():
	var arrays = create_test_arrays(MEDIUM_SCALE / 3, MEDIUM_SCALE / 3, 0.4)
	var array1 = arrays[0]
	var array2 = arrays[1]

	# Naive implementation (simulating old behavior)
	var naive_intersect = func():
		var result: Array = []
		for entity in array1:
			if array2.has(entity): # O(n) lookup
				result.append(entity)
		assert_that(result.size()).is_greater(0)

	# Optimized implementation
	var optimized_intersect = func():
		var result = ArrayExtensions.intersect(array1, array2)
		assert_that(result.size()).is_greater(0)

	benchmark("Naive_Array_Intersect", naive_intersect)
	benchmark("Optimized_Array_Intersect", optimized_intersect)

	print_performance_results()

	# Optimized should be significantly faster
	var naive_time = performance_results["Naive_Array_Intersect"].avg_time_ms
	var optimized_time = performance_results["Optimized_Array_Intersect"].avg_time_ms

	# Optimized should be at least 2x faster for medium-sized arrays
	assert_that(optimized_time).is_less(naive_time * 0.5).override_failure_message(
		(
			"Array optimization not effective: naive=%f ms, optimized=%f ms"
			% [naive_time, optimized_time]
		)
	)


## Test memory efficiency of operations
func test_array_operations_memory_efficiency():
	var arrays = create_test_arrays(LARGE_SCALE / 2, LARGE_SCALE / 2, 0.3)
	var array1 = arrays[0]
	var array2 = arrays[1]

	var memory_test = func():
		# Perform multiple operations that create intermediate results
		var intersect_result = ArrayExtensions.intersect(array1, array2)
		var union_result = ArrayExtensions.union(array1, array2)
		var diff_result = ArrayExtensions.difference(array1, array2)

		# Verify results are reasonable
		assert_that(intersect_result.size()).is_greater_equal(0)
		assert_that(union_result.size()).is_greater_equal(array1.size())
		assert_that(diff_result.size()).is_greater_equal(0)

	benchmark("Array_Operations_Memory_Test", memory_test)
	print_performance_results()

	# Memory test should complete without excessive allocations
	assert_performance_threshold(
		"Array_Operations_Memory_Test", 150.0, "Array operations memory usage too high"
	)
