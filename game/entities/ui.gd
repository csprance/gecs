## A Ui entity represent a UI element that has a CanvasLayer if we add a UiVisibility
## Component to the entity it will show up in the world
class_name UiEntity
extends Entity

@onready var canvas_layer: CanvasLayer = $CanvasLayer

func on_ready():
	# Hide it on startup
	canvas_layer.visible = false

