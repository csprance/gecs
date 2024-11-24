class_name C_LookAt
extends Component

@export var target: Vector3 = Vector3.ZERO

@export var debug: bool = true

func _init(_target: Vector3 = Vector3.ZERO, _debug: bool = true) -> void:
    target = _target
    debug = _debug