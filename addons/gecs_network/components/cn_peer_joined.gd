class_name CN_PeerJoined
extends Component
## Transient event component: emitted when a new peer joins the session.
## Added to the session entity for one frame, then cleared by NetworkSession.

@export var peer_id: int = 0


func _init(p_id: int = 0) -> void:
	peer_id = p_id
