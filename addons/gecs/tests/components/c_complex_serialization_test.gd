class_name C_ComplexSerializationTest
extends Component

@export var array_value: Array[int] = [1, 2, 3, 4, 5]
@export var string_array: Array[String] = ["hello", "world", "test"]
@export var dict_value: Dictionary = {"key1": "value1", "key2": 123, "key3": true}
@export var empty_array: Array = []
@export var empty_dict: Dictionary = {}

func _init(
	_array_value: Array[int] = [1, 2, 3, 4, 5],
	_string_array: Array[String] = ["hello", "world", "test"],
	_dict_value: Dictionary = {"key1": "value1", "key2": 123, "key3": true},
	_empty_array: Array = [],
	_empty_dict: Dictionary = {}
):
	array_value = _array_value
	string_array = _string_array
	dict_value = _dict_value
	empty_array = _empty_array
	empty_dict = _empty_dict
