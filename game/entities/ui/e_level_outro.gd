class_name LevelOutroUI
extends Ui

var victims : Array[Entity]
var reward_items : Array[Entity]
@onready var lifes: Array[TextureRect] = [%Life1, %Life2, %Life3, %Life4, %Life5]

func on_ready():
	# Grab the Number of lives from game state
	for idx in range(GameState.lives):
		lifes[idx].visible = true
	# Grab 
	pass
