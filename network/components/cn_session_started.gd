class_name CN_SessionStarted
extends Component
## Transient event component: emitted when a multiplayer session starts.
## Added to the session entity for one frame, then cleared by NetworkSession.

@export var is_host: bool = false


func _init(p_is_host: bool = false) -> void:
	is_host = p_is_host
