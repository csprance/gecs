class_name GameStateSystem
extends System

var _score = 0
var _lives = 0
var _blocks = -1

func query() -> QueryBuilder:
	return q.with_all([C_GameState]) 

## When the lives are lost the game is over.
## When the blocks are destroyed the game is won.
func process(_e, _d) -> void:
	var game_state = GameStateUtils.get_game_state()

	# Score Changed
	if _blocks != game_state.blocks:
		Loggie.debug('Blocks:', game_state.blocks)
		_blocks = game_state.blocks
	
	# Win State
	if _blocks == 0:
		Loggie.debug('Game Won')
		for ui in ECS.world.query.with_all([C_WinUi]).with_none([C_UiVisibility]).execute():
			ui.add_component(C_UiVisibility.new())
		get_tree().paused = true
	
	# Lose State		
	if game_state.lives <= 0:
		Loggie.debug('Game Lost')
		for ui in ECS.world.query.with_all([C_LoseUi]).with_none([C_UiVisibility]).execute():
			ui.add_component(C_UiVisibility.new())
		get_tree().paused = true
	
	

