# GameState Autoload
extends Node

signal game_paused
signal game_unpaused

signal score_changed(score: int)

var paused :bool = false:
	get:
		return paused
	set(v):
		paused = v
		if v:
			game_paused.emit()
		else:
			game_unpaused.emit()


var player_1_score :int = 0

var player_2_score :int = 0
