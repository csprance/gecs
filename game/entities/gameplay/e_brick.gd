## Brick Entity.
##
## Represents a destructible brick in the game.
## Handles collision with the ball and applies damage when hit.
## Contains components for health and handles bounce behavior.
class_name Brick
extends Entity


# Assuming the Brick has a CollisionShape2D for collision
func on_ready() -> void:
	Utils.sync_transform(self)
