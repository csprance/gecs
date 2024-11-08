## Paddle Entity.
##
## Represents the player's paddle.
## Handles player input for movement and bouncing the ball upon collision.
## When an entity enters its area, it adds a `Bounced` component to that entity with the paddle's normal.
class_name Paddle
extends Entity

@export var normal := Vector2(0, 1)  # Adjust based on your bumper's orientation
## The maximum amonunt the normal is rotated based on the distance from the paddle
@export var max_rot := 33.0

var paddle_width := 100.0
var last_normal:Vector2

func on_ready() -> void:
	Utils.sync_transform(self)
