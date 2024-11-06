## PlayerMovement Component.[br]
## Used to control player input for moving the [Paddle].
## Stores the movement axis and speed.
class_name PlayerMovement
extends Component

## What direction we have been directed to move in
@export var axis := Vector2.ZERO
## How fast the player moves
@export var speed := 1000


