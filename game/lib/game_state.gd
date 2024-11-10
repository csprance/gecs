# GameState Autoload
extends Node

var score :int = 0:
	get:
		return score
	set(v):
		score = v

var bricks  :int = 15 :
	get:
		return bricks
	set(v):
		bricks = v
		if bricks == 0:
			show_game_won()

var lives :int = 3 :
	get:
		return lives
	set(v):
		lives = v
		if lives == 0:
			show_game_lost()


func show_game_won():
	Loggie.debug('Game Won')
	for ui in ECS.world.query.with_all([C_WinUi]).with_none([C_UiVisibility]).execute():
		ui.add_component(C_UiVisibility.new())
	get_tree().paused = true

func show_game_lost():	
	Loggie.debug('Game Lost')
	for ui in ECS.world.query.with_all([C_LoseUi]).with_none([C_UiVisibility]).execute():
		ui.add_component(C_UiVisibility.new())
	get_tree().paused = true