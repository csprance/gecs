class_name C_Transform
extends Component

@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO


func _init(_pos: Vector3 = Vector3.ZERO, _rot: Vector3 = Vector3.ZERO) -> void:
	position = _pos
	rotation = _rot
