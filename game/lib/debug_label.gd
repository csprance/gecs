@tool
class_name DebugLabel
extends Sprite3D

@export var debug_text: String = "Debug Label"
@onready var label:  Label = %Label
@onready var viewport: SubViewport = %SubViewport

func _process(delta: float) -> void:
    label.text = debug_text
    viewport.size = label.get_rect().size
    