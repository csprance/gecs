extends GdUnitTestSuite



func test_component_key_is_set_correctly():
	# Create an instance of a concrete Component subclass
	var component = C_TestA.new()
	# The key should be set to the resource path of the component's script
	var expected_key = component.get_script().resource_path
	assert_str("res://addons/gecs/tests/components/c_test_a.gd").is_equal(expected_key)


func test_component_query_matcher_equality():
	# Test _eq operator
	var component = C_TestA.new(42)

	# Should match exact value
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_eq": 42}})).is_true()
	# Should not match different value
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_eq": 10}})).is_false()


func test_component_query_matcher_inequality():
	# Test _ne operator
	var component = C_TestA.new(42)

	# Should match different value
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_ne": 10}})).is_true()
	# Should not match same value
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_ne": 42}})).is_false()


func test_component_query_matcher_greater_than():
	# Test _gt and _gte operators
	var component = C_TestA.new(50)

	# _gt tests
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gt": 49}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gt": 50}})).is_false()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gt": 51}})).is_false()

	# _gte tests
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gte": 49}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gte": 50}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gte": 51}})).is_false()


func test_component_query_matcher_less_than():
	# Test _lt and _lte operators
	var component = C_TestA.new(50)

	# _lt tests
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_lt": 51}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_lt": 50}})).is_false()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_lt": 49}})).is_false()

	# _lte tests
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_lte": 51}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_lte": 50}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_lte": 49}})).is_false()


func test_component_query_matcher_array_membership():
	# Test _in and _nin operators
	var component = C_TestA.new(42)

	# _in tests
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_in": [40, 41, 42]}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_in": [1, 2, 3]}})).is_false()

	# _nin tests
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_nin": [1, 2, 3]}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_nin": [40, 41, 42]}})).is_false()


func test_component_query_matcher_custom_function():
	# Test func operator
	var component = C_TestA.new(42)

	# Custom function that checks if value is even
	var is_even = func(val): return val % 2 == 0
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"func": is_even}})).is_true()

	# Custom function that checks if value is odd
	var is_odd = func(val): return val % 2 == 1
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"func": is_odd}})).is_false()

	# Custom function with complex logic
	var in_range = func(val): return val >= 40 and val <= 50
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"func": in_range}})).is_true()


func test_component_query_matcher_multiple_operators():
	# Test combining multiple operators (all must pass)
	var component = C_TestA.new(50)

	# Should match: value >= 40 AND value <= 60
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gte": 40, "_lte": 60}})).is_true()

	# Should not match: value >= 40 AND value <= 45
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_gte": 40, "_lte": 45}})).is_false()

	# Should match: value != 0 AND value > 30
	assert_bool(ComponentQueryMatcher.matches_query(component, {"value": {"_ne": 0, "_gt": 30}})).is_true()


func test_component_query_matcher_falsy_values():
	# Test that falsy values (0, false, null) are handled correctly
	var component_zero = C_TestA.new(0)

	# Should match 0 exactly
	assert_bool(ComponentQueryMatcher.matches_query(component_zero, {"value": {"_eq": 0}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component_zero, {"value": {"_eq": 1}})).is_false()

	# Should handle 0 in ranges
	assert_bool(ComponentQueryMatcher.matches_query(component_zero, {"value": {"_gte": 0}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component_zero, {"value": {"_lte": 0}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component_zero, {"value": {"_gt": 0}})).is_false()

	# Should handle negative numbers
	var component_negative = C_TestA.new(-5)
	assert_bool(ComponentQueryMatcher.matches_query(component_negative, {"value": {"_eq": -5}})).is_true()
	assert_bool(ComponentQueryMatcher.matches_query(component_negative, {"value": {"_lt": 0}})).is_true()


func test_component_query_matcher_empty_query():
	# Empty query should match any component
	var component = C_TestA.new(42)
	assert_bool(ComponentQueryMatcher.matches_query(component, {})).is_true()


func test_component_query_matcher_nonexistent_property():
	# Should return false if property doesn't exist
	var component = C_TestA.new(42)
	assert_bool(ComponentQueryMatcher.matches_query(component, {"nonexistent": {"_eq": 10}})).is_false()


func test_component_query_matcher_multiple_properties():
	# Test querying multiple properties at once
	var component = C_TestD.new(5)  # Has 'points' property

	# Both properties must match
	assert_bool(ComponentQueryMatcher.matches_query(component, {
		"points": {"_eq": 5}
	})).is_true()

	assert_bool(ComponentQueryMatcher.matches_query(component, {
		"points": {"_eq": 10}
	})).is_false()


func test_component_serialization():
	# Create an instance of a concrete Component subclass
	var component_a = C_TestA.new(42)
	var component_b = C_TestD.new(1)

	# Serialize the component
	var serialized_data_a = component_a.serialize()
	var serialized_data_b = component_b.serialize()

	# Check if the serialized data matches the expected values
	assert_int(serialized_data_a["value"]).is_equal(42)
	assert_int(serialized_data_b["points"]).is_equal(1)
