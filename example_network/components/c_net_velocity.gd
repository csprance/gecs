class_name C_NetVelocity
extends Component
## Velocity component for network example.
## Uses "direction" to differentiate from example/'s C_Velocity.

## Movement direction and speed combined as a vector
@export var direction: Vector3 = Vector3.ZERO


func _init(initial_dir: Vector3 = Vector3.ZERO) -> void:
	direction = initial_dir
