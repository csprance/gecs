# Set.gd
class_name Set
extends RefCounted

var _data: Dictionary = {}

func _init(data = null) -> void:
	if data:
		if data is Array:
			for value in data:
				_data[value] = true
		elif data is Set:
			for value in data._data.keys():
				_data[value] = true
		elif data is Dictionary:
			for key in data.keys():
				_data[key] = true

# --- Basic operations ---

func add(value) -> void:
	_data[value] = true

func erase(value) -> void:
	_data.erase(value)

func has(value) -> bool:
	return _data.has(value)

func clear() -> void:
	_data.clear()

func size() -> int:
	return _data.size()

func is_empty() -> bool:
	return _data.is_empty()

func values() -> Array:
	return _data.keys()

# --- Set algebra ---

func union(other: Set) -> Set:
	var result = Set.new()
	result._data = _data.duplicate()
	for key in other._data.keys():
		result._data[key] = true
	return result

func intersect(other: Set) -> Set:
	if other.size() < _data.size():
		return other.intersect(self)
		
	var result = Set.new()
	for key in _data.keys():
		if other._data.has(key):
			result._data[key] = true
	return result

func difference(other: Set) -> Set:
	var result = Set.new()
	for key in _data.keys():
		if not other._data.has(key):
			result._data[key] = true
	return result

func symmetric_difference(other: Set) -> Set:
	var result = Set.new()
	for key in _data.keys():
		if not other._data.has(key):
			result._data[key] = true
	for key in other._data.keys():
		if not _data.has(key):
			result._data[key] = true
	return result

# --- Subset/superset checks ---

func is_subset(other: Set) -> bool:
	for key in _data.keys():
		if not other._data.has(key):
			return false
	return true

func is_superset(other: Set) -> bool:
	return other.is_subset(self)

func is_equal(other) -> bool:
	if _data.size() != other._data.size():
		return false
	return self.is_subset(other)

# --- Helpers ---

func duplicate() -> Set:
	var result = Set.new()
	result._data = _data.duplicate()
	return result

func to_array() -> Array:
	return _data.keys()