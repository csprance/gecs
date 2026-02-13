class_name C_PlayerNumber
extends Component
## Player number component (1-4) based on join order, not peer_id.
## Used for assigning fixed colors: 1=Blue, 2=Red, 3=Green, 4=Yellow.

@export var player_number: int = 0

func _init(number: int = 0) -> void:
	player_number = number
