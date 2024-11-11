## Brick Entity.
##
## Represents a destructible brick in the game.
## Handles collision with the ball and applies damage when hit.
## Contains components for health and handles bounce behavior.
class_name Brick
extends Entity

@onready var sprite: Sprite2D = %Sprite
@export var color: Color

var cracked_amt := 0.0:
    set(value):
        cracked_amt = value
        sprite.material.set_shader_parameter("cracked_amt", value)

# Assuming the Brick has a CollisionShape2D for collision
func on_ready() -> void:
    Utils.sync_transform(self)
    sprite.material = sprite.material.duplicate()
    sprite.material.set_shader_parameter("brick_color", color)
    sprite.material.set_shader_parameter("cracked_amt", cracked_amt)