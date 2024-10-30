class_name Ball
extends Entity


@onready var ball: Ball = $'.'

func _ready() -> void:
	var trs: Transform = get_component('transform')
	trs.position = ball.position
	trs.scale = ball.scale
	trs.rotation = ball.rotation
		
	

	
