class_name Paddle
extends Entity


func _ready() -> void:
	var trs: Transform = get_component('transform')
	trs.position = self.position
	trs.scale = self.scale
	trs.rotation = self.rotation
