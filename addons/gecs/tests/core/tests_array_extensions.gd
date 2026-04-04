extends GdUnitTestSuite


var testSystemA: TestASystem
var testSystemB: TestBSystem
var testSystemC: TestCSystem
var testSystemD: TestDSystem


func before_test():
	testSystemA = auto_free(TestASystem.new())
	testSystemB = auto_free(TestBSystem.new())
	testSystemC = auto_free(TestCSystem.new())
	testSystemD = auto_free(TestDSystem.new())


func test_topological_sort():
	# Create a dictionary of systems by group
	var systems_by_group = {
		"Group1":
		[
			testSystemD,
			testSystemB,
			testSystemC,
			testSystemA,
		],
		"Group2":
		[
			testSystemB,
			testSystemD,
			testSystemA,
			testSystemC,
		]
	}

	var expected_sorted_systems = {
		"Group1":
		[
			testSystemA,
			testSystemB,
			testSystemC,
			testSystemD,
		],
		"Group2":
		[
			testSystemA,
			testSystemB,
			testSystemC,
			testSystemD,
		]
	}

	# Sorts the dict in place
	ArrayExtensions.topological_sort(systems_by_group)

	# Check if the systems are sorted correctly
	for group in systems_by_group.keys():
		assert_array(systems_by_group[group]).is_equal(expected_sorted_systems[group])
