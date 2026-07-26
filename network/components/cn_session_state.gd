class_name CN_SessionState
extends Component
## Permanent state component: tracks live connection state for the session entity.
## Kept on the session entity throughout the session lifetime.

@export var is_connected: bool = false
@export var is_hosting: bool = false
@export var peer_count: int = 0
