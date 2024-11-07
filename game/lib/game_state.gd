class_name GameStateUtils

## A Quick way to get the [GameState] component from the [ActiveGameEntity]
## If entity=true it will get the entity holding game state instead of the component
static func get_game_state() -> C_GameState:
	var game_state_ent = get_active_game_state_entity()
	if game_state_ent:
		return game_state_ent.get_component(C_GameState) as C_GameState
	return C_GameState.new()

static func get_active_game_state_entity() -> ActiveGame:
	for game_state_ent in ECS.world.query.with_all([C_GameState]).execute():
		return game_state_ent as ActiveGame
	
	assert(false, "No ActiveGameEntity found")
	return
