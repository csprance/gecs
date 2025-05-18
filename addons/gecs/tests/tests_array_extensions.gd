extends GdUnitTestSuite

const TestSystemA = preload("res://addons/gecs/tests/systems/s_test_a.gd")
const TestSystemB = preload("res://addons/gecs/tests/systems/s_test_b.gd")
const TestSystemC = preload("res://addons/gecs/tests/systems/s_test_c.gd")
const TestSystemD = preload("res://addons/gecs/tests/systems/s_test_d.gd")

var testSystemA = TestSystemA.new()
var testSystemB = TestSystemB.new()
var testSystemC = TestSystemC.new()
var testSystemD = TestSystemD.new()


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
