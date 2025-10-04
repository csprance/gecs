extends Component
class_name C_SerializationTest

@export var int_value: int = 42
@export var float_value: float = 3.14
@export var string_value: String = "test_string"
@export var bool_value: bool = true
@export var vector2_value: Vector2 = Vector2(1.0, 2.0)
@export var vector3_value: Vector3 = Vector3(1.0, 2.0, 3.0)
@export var color_value: Color = Color.RED

func _init(
	_int_value: int = 42,
	_float_value: float = 3.14,
	_string_value: String = "test_string",
	_bool_value: bool = true,
	_vector2_value: Vector2 = Vector2(1.0, 2.0),
	_vector3_value: Vector3 = Vector3(1.0, 2.0, 3.0),
	_color_value: Color = Color.RED
):
	int_value = _int_value
	float_value = _float_value
	string_value = _string_value
	bool_value = _bool_value
	vector2_value = _vector2_value
	vector3_value = _vector3_value
	color_value = _color_value
