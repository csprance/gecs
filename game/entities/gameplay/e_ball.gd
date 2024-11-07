## Ball Entity.
##
## Represents the ball in the game.
## Contains components for movement, collision, and bouncing behavior.
class_name Ball
extends Entity

@export var ball_speed := 300

func on_ready() -> void:
	Utils.sync_transform(self)
