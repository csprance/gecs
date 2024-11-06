class_name GameStateSystem
extends System

var _score = 0
var _lives = 0
var _blocks = 0

func query() -> QueryBuilder:
	return q.with_all([GameState]) 

## When the lives are lost the game is over.
## When the blocks are destroyed the game is won.
func process(_e, _d) -> void:
	var game_state = GameStateUtils.get_game_state()
	var changed = Utils.all([
		_score == game_state.score,
		_lives == game_state.lives,
		_blocks == game_state.blocks
	])
	if not changed:
		return

	_score = game_state.score
	_lives = game_state.lives
	_blocks = game_state.blocks

	
	if game_state.lives <= 0:
		get_tree().quit()
	
	Loggie.debug('Blocks:', game_state.blocks)

