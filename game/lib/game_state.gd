# GameState Autoload
extends Node

var score :int = 0:
	get:
		return score
	set(v):
		score = v

var lives :int = 3 :
	get:
		return lives
	set(v):
		lives = v
		if lives == 0:
			print('Game Lost')

var active_weapon :
	get:
		return active_weapon
	set(v):
		active_weapon = v

var active_item:
	get:
		return active_item
	set(v):
		active_item = v