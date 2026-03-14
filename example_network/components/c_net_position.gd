class_name C_NetPosition
extends Component
## Position component for network example.
## Uses @export_group("SPAWN_ONLY") so CN_NetSync sends this value once at spawn
## and never replicates it again — clients simulate locally after that.

@export_group("SPAWN_ONLY")
@export var position: Vector3 = Vector3.ZERO


func _init(initial_pos: Vector3 = Vector3.ZERO) -> void:
	position = initial_pos
