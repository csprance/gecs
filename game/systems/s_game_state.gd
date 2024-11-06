class_name GameStateSystem
extends System

func query(q: QueryBuilder) -> QueryBuilder:
	return q.with_all([GameState]) 

## When the lives are lost the game is over.
## When the blocks are destroyed the game is won.
func process(entity: Entity, delta: float) -> void:
	var game_state = GameStateUtils.get_game_state()
	if game_state.lives <= 0:
		get_tree().quit()
	Loggie.debug('Blocks:', game_state.blocks)

