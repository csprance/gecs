@tool
class_name DebugLabel
extends Sprite3D

## The text label to display
@export var text: String = "Debug Label"

@onready var label:  Label = %Label
@onready var viewport: SubViewport = %SubViewport


func _process(delta: float) -> void:
    label.text = text
    viewport.size = label.get_rect().size
    