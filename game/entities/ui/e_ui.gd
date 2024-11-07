class_name Ui
extends Entity

@onready var canvas_layer: CanvasLayer = $CanvasLayer

func on_ready():
	# Hide it on startup
	canvas_layer.visible = false