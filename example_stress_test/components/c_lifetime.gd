class_name C_Lifetime
extends Component


@export var lifetime: float = 15.0 # Time in seconds before the entity is removed


func _init(_min: float = 1.0, _max: float = 10.0):
	lifetime = randf_range(_min, _max)
