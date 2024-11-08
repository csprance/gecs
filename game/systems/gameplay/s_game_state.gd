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

	if _blocks != game_state.blocks:
		Loggie.debug('Blocks:', game_state.blocks)
		_blocks = game_state.blocks
	if _blocks == 0:
		Loggie.debug('Game Won')
		get_tree().paused = true
		
	if game_state.lives <= 0:
		get_tree().quit()
	
	

