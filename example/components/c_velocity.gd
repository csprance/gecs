class_name C_Velocity
extends Component


@export var velocity: Vector3


func _init(_vel: Vector3 = Vector3.ZERO) -> void:
    velocity = _vel