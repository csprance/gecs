extends Component
class_name Bounced

@export var normal = Vector2.AXIS_Y

func _init(_normal: Vector2):
	key = get_script().resource_path
	normal = _normal
