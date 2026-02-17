class_name C_PlayerInput
extends SyncComponent
## Player input component - synced to server for authoritative game state.
## Extends SyncComponent for automatic change detection and sync.

## Movement input direction (WASD/Arrow keys normalized)
var move_direction: Vector2 = Vector2.ZERO

## Whether shoot key is pressed (Space)
@export var is_shooting: bool = false

## Direction to shoot (facing direction)
@export var shoot_direction: Vector3 = Vector3.FORWARD
