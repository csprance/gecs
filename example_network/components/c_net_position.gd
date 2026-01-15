class_name C_NetPosition
extends Component
## Position component for network example.
## The @export allows NetworkSync to serialize and sync this value during spawn.

@export var position: Vector3 = Vector3.ZERO


func _init(initial_pos: Vector3 = Vector3.ZERO) -> void:
	position = initial_pos
