## Velocity Component.[br]
## Represents the velocity of an entity, including its direction and speed.
## Used by the [VelocitySystem] to move entities each frame.
class_name C_Velocity
extends Component

@export var velocity := Vector3.ZERO

func _init(_velocity: Vector3 = velocity) -> void:
    velocity = _velocity