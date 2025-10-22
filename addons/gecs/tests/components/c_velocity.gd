## Test velocity component for observer performance tests
class_name C_TestVelocity
extends Component

@export var velocity: Vector3 = Vector3.ZERO : set = set_velocity

func set_velocity(new_vel: Vector3):
	var old_vel = velocity
	velocity = new_vel
	# Emit signal for observers to detect the change
	property_changed.emit(self, "velocity", old_vel, new_vel)

func _init(_velocity: Vector3 = Vector3.ZERO):
	velocity = _velocity
