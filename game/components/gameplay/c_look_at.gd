class_name C_LookAt
extends Component

@export var target: Vector3 = Vector3.ZERO
@export var turn_speed: float = 5.0  # Default turn speed
@export var debug: bool = false

func _init(_target: Vector3 = Vector3.ZERO, _turn_speed: float = 5.0, _debug: bool = true) -> void:
    target = _target
    turn_speed = _turn_speed
    debug = _debug