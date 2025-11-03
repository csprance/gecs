## Set is Mathematical set data structure for collections of unique values.[br]
##
## Built on Dictionary for O(1) membership testing. Used throughout GECS for
## entity filtering and component indexing.
##
## Supports standard set operations like union, intersection, and difference.
## No inherent ordering - elements are stored by hash.
##
## [codeblock]
##     var numbers = Set.new([1, 2, 3, 4, 5])
##     numbers.add(6)
##     print(numbers.has(3))  # true
##
##     var set_a = Set.new([1, 2, 3, 4])
##     var set_b = Set.new([3, 4, 5, 6])
##     var intersection = set_a.intersect(set_b)  # [3, 4]
## [/codeblock]
class_name Set
extends RefCounted

## Internal storage using Dictionary keys for O(1) average-case operations.
## Values in the dictionary are always [code]true[/code] and ignored.
var _data: Dictionary = {}


## Initializes a new Set from Array, Dictionary keys, or another Set.
## [param data]: Optional initial data. Duplicates are automatically removed.
func _init(data = null) -> void:
	if data:
		if data is Array:
			# Add array elements, automatically deduplicating
			for value in data:
				_data[value] = true
		elif data is Set:
			# Copy from another set
			for value in data._data.keys():
				_data[value] = true
		elif data is Dictionary:
			# Use dictionary keys as set elements
			for key in data.keys():
				_data[key] = true

#region Basic Set Operations


## Adds a value to the set. Has no effect if the value is already present.
## [param value]: The value to add to the set. Can be any hashable type.
##
## [b]Time Complexity:[/b] O(1) average case
## [codeblock]
##     var my_set = Set.new([1, 2, 3])
##     my_set.add(4)      # Set now contains [1, 2, 3, 4]
##     my_set.add(2)      # No change, 2 already exists
## [/codeblock]
func add(value) -> void:
	_data[value] = true


## Removes a value from the set. Has no effect if the value is not present.
## [param value]: The value to remove from the set
##
## [b]Time Complexity:[/b] O(1) average case
## [codeblock]
##     var my_set = Set.new([1, 2, 3, 4])
##     my_set.erase(3)    # Set now contains [1, 2, 4]
##     my_set.erase(5)    # No change, 5 doesn't exist
## [/codeblock]
func erase(value) -> void:
	_data.erase(value)


## Tests whether a value exists in the set.
## [param value]: The value to test for membership
## [return]: [code]true[/code] if the value exists in the set, [code]false[/code] otherwise
##
## [b]Time Complexity:[/b] O(1) average case
## [codeblock]
##     var my_set = Set.new(["apple", "banana", "cherry"])
##     print(my_set.has("banana"))  # true
##     print(my_set.has("grape"))   # false
## [/codeblock]
func has(value) -> bool:
	return _data.has(value)


## Removes all elements from the set, making it empty.
## [b]Time Complexity:[/b] O(1)
## [codeblock]
##     var my_set = Set.new([1, 2, 3, 4, 5])
##     my_set.clear()
##     print(my_set.is_empty())  # true
## [/codeblock]
func clear() -> void:
	_data.clear()


## Returns the number of elements in the set.
## [return]: Integer count of unique elements in the set
##
## [b]Time Complexity:[/b] O(1)
## [codeblock]
##     var my_set = Set.new(["a", "b", "c", "a", "b"])  # Duplicates ignored
##     print(my_set.size())  # 3
## [/codeblock]
func size() -> int:
	return _data.size()


## Tests whether the set contains no elements.
## [return]: [code]true[/code] if the set is empty, [code]false[/code] otherwise
##
## [b]Time Complexity:[/b] O(1)
## [codeblock]
##     var empty_set = Set.new()
##     var filled_set = Set.new([1, 2, 3])
##     print(empty_set.is_empty())   # true
##     print(filled_set.is_empty())  # false
## [/codeblock]
func is_empty() -> bool:
	return _data.is_empty()


## Returns all elements in the set as an Array.
## The order of elements is not guaranteed and may vary between calls.
## [return]: Array containing all set elements
##
## [b]Time Complexity:[/b] O(n) where n is the number of elements
## [codeblock]
##     var my_set = Set.new([3, 1, 4, 1, 5])
##     var elements = my_set.values()  # [1, 3, 4, 5] (order may vary)
## [/codeblock]
func values() -> Array:
	return _data.keys()

#endregion

#region Set Algebra Operations


## Returns the union of this set with another set (A ∪ B).
## Creates a new set containing all elements that exist in either set.
## [param other]: The other set to union with
## [return]: New [Set] containing all elements from both sets
##
## [b]Time Complexity:[/b] O(|A| + |B|) where |A| and |B| are set sizes
## [codeblock]
##     var set_a = Set.new([1, 2, 3])
##     var set_b = Set.new([3, 4, 5])
##     var union_set = set_a.union(set_b)  # Contains [1, 2, 3, 4, 5]
## [/codeblock]
func union(other: Set) -> Set:
	var result = Set.new()
	result._data = _data.duplicate()
	for key in other._data.keys():
		result._data[key] = true
	return result


## Returns the intersection of this set with another set (A ∩ B).
## Creates a new set containing only elements that exist in both sets.
## Automatically optimizes by iterating over the smaller set.
## [param other]: The other set to intersect with
## [return]: New [Set] containing elements common to both sets
##
## [b]Time Complexity:[/b] O(min(|A|, |B|)) - optimized for smaller set
## [codeblock]
##     var set_a = Set.new([1, 2, 3, 4])
##     var set_b = Set.new([3, 4, 5, 6])
##     var intersection = set_a.intersect(set_b)  # Contains [3, 4]
## [/codeblock]
func intersect(other: Set) -> Set:
	# Optimization: iterate over smaller set for better performance
	if other.size() < _data.size():
		return other.intersect(self )

	var result = Set.new()
	for key in _data.keys():
		if other._data.has(key):
			result._data[key] = true
	return result


## Returns the difference of this set minus another set (A - B).
## Creates a new set containing elements in this set but not in the other.
## [param other]: The set whose elements to exclude
## [return]: New [Set] containing elements only in this set
##
## [b]Time Complexity:[/b] O(|A|) where |A| is the size of this set
## [codeblock]
##     var set_a = Set.new([1, 2, 3, 4])
##     var set_b = Set.new([3, 4, 5, 6])
##     var difference = set_a.difference(set_b)  # Contains [1, 2]
## [/codeblock]
func difference(other: Set) -> Set:
	var result = Set.new()
	for key in _data.keys():
		if not other._data.has(key):
			result._data[key] = true
	return result


## Returns the symmetric difference of this set with another set (A ⊕ B).
## Creates a new set containing elements in either set, but not in both.
## Equivalent to (A - B) ∪ (B - A).
## [param other]: The other set for symmetric difference
## [return]: New [Set] containing elements in exactly one of the two sets
##
## [b]Time Complexity:[/b] O(|A| + |B|)
## [codeblock]
##     var set_a = Set.new([1, 2, 3, 4])
##     var set_b = Set.new([3, 4, 5, 6])
##     var sym_diff = set_a.symmetric_difference(set_b)  # Contains [1, 2, 5, 6]
## [/codeblock]
func symmetric_difference(other: Set) -> Set:
	var result = Set.new()
	# Add elements from this set that aren't in other
	for key in _data.keys():
		if not other._data.has(key):
			result._data[key] = true
	# Add elements from other set that aren't in this set
	for key in other._data.keys():
		if not _data.has(key):
			result._data[key] = true
	return result

#endregion

#region Set Relationship Testing


## Tests whether this set is a subset of another set (A ⊆ B).
## Returns [code]true[/code] if every element in this set also exists in the other set.
## [param other]: The potential superset to test against
## [return]: [code]true[/code] if this set is a subset of other, [code]false[/code] otherwise
##
## [b]Time Complexity:[/b] O(|A|) where |A| is the size of this set
## [codeblock]
##     var small_set = Set.new([1, 2])
##     var large_set = Set.new([1, 2, 3, 4, 5])
##     print(small_set.is_subset(large_set))  # true
##     print(large_set.is_subset(small_set))  # false
## [/codeblock]
func is_subset(other: Set) -> bool:
	for key in _data.keys():
		if not other._data.has(key):
			return false
	return true


## Tests whether this set is a superset of another set (A ⊇ B).
## Returns [code]true[/code] if this set contains every element from the other set.
## [param other]: The potential subset to test
## [return]: [code]true[/code] if this set is a superset of other, [code]false[/code] otherwise
##
## [b]Time Complexity:[/b] O(|B|) where |B| is the size of the other set
## [codeblock]
##     var large_set = Set.new([1, 2, 3, 4, 5])
##     var small_set = Set.new([2, 4])
##     print(large_set.is_superset(small_set))  # true
## [/codeblock]
func is_superset(other: Set) -> bool:
	return other.is_subset(self )


## Tests whether this set contains exactly the same elements as another set (A = B).
## Two sets are equal if they have the same size and this set is a subset of the other.
## [param other]: The set to compare for equality
## [return]: [code]true[/code] if sets contain identical elements, [code]false[/code] otherwise
##
## [b]Time Complexity:[/b] O(min(|A|, |B|)) - fails fast on size mismatch
## [codeblock]
##     var set_a = Set.new([1, 2, 3])
##     var set_b = Set.new([3, 1, 2])  # Order doesn't matter
##     var set_c = Set.new([1, 2, 3, 4])
##     print(set_a.is_equal(set_b))  # true
##     print(set_a.is_equal(set_c))  # false
## [/codeblock]
func is_equal(other) -> bool:
	# Quick size check for early exit
	if _data.size() != other._data.size():
		return false
	return self.is_subset(other)

#endregion

#region Utility Methods


## Creates a shallow copy of this set.
## The returned set is independent - modifications to either set won't affect the other.
## However, if the set contains reference types, the references are shared.
## [return]: New [Set] containing the same elements
##
## [b]Time Complexity:[/b] O(n) where n is the number of elements
## [codeblock]
##     var original = Set.new([1, 2, 3])
##     var copy = original.duplicate()
##     copy.add(4)                    # Only affects copy
##     print(original.size())         # 3
##     print(copy.size())             # 4
## [/codeblock]
func duplicate() -> Set:
	var result = Set.new()
	result._data = _data.duplicate()
	return result


## Converts the set to an Array containing all elements.
## This is an alias for [method values] provided for API consistency.
## The order of elements is not guaranteed.
## [return]: Array containing all set elements
##
## [b]Time Complexity:[/b] O(n) where n is the number of elements
## [codeblock]
##     var my_set = Set.new(["x", "y", "z"])
##     var array = my_set.to_array()  # ["x", "y", "z"] (order may vary)
## [/codeblock]
func to_array() -> Array:
	return _data.keys()

#endregion
