class_name C_NetPosition
extends Component
## Position component for network example.
## Synced at HIGH priority (~20 Hz). Remote clients interpolate between updates
## using velocity for smooth movement (see S_NetworkMovement).

@export_group(CN_NetSync.HIGH)
@export var position: Vector3 = Vector3.ZERO


func _init(initial_pos: Vector3 = Vector3.ZERO) -> void:
	position = initial_pos
