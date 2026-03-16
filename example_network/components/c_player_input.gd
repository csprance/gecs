class_name C_PlayerInput
extends Component
## Player input component - synced to server for authoritative game state.
## Uses @export_group(CN_NetSync.HIGH) so CN_NetSync prioritizes these properties at ~20 Hz.

@export_group(CN_NetSync.HIGH)
## Movement input direction (WASD/Arrow keys normalized)
var move_direction: Vector2 = Vector2.ZERO

## Whether shoot key is pressed (Space)
@export var is_shooting: bool = false

## Direction to shoot (facing direction)
@export var shoot_direction: Vector3 = Vector3.FORWARD
