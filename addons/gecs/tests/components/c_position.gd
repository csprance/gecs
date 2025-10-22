## Test position component for observer performance tests
class_name C_TestPosition
extends Component

@export var position: Vector3 = Vector3.ZERO : set = set_position

func set_position(new_pos: Vector3):
	var old_pos = position
	position = new_pos
	# Emit signal for observers to detect the change
	property_changed.emit(self, "position", old_pos, new_pos)

func _init(_position: Vector3 = Vector3.ZERO):
	position = _position
