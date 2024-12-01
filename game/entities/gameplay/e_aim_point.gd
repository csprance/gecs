@tool
class_name AimPoint
extends Entity

@onready var sprite_2d := $Sprite2D as Sprite2D
@export var color :Color = Color(1, 1, 1, 1):
    set(v):
        color = v
        change_color()

# Change color of the Sprite2D modulate
func change_color():
    sprite_2d.modulate = color
