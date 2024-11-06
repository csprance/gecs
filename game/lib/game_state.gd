class_name GameStateUtils

## A Quick way to get the [GameState] component from the [GameStateEntity]
static func get_game_state() -> GameState:
	var game_state_ents = ECS.buildQuery().with_all([GameState]).execute()
	for game_state_ent in game_state_ents:
		return game_state_ent.get_component(GameState) as GameState
	
	assert(false, "No GameState entity found")
	return
