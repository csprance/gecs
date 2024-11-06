class_name GameStateUtils

## A Quick way to get the [GameState] component from the [ActiveGameEntity]
## If entity=true it will get the entity holding game state instead of the component
static func get_game_state() -> GameState:
	var game_state_ent = get_active_game_state_entity()
	if game_state_ent:
		return game_state_ent.get_component(GameState) as GameState
	return GameState.new()

static func get_active_game_state_entity() -> ActiveGameEntity:
	for game_state_ent in ECS.world.query.with_all([GameState]).execute():
		return game_state_ent as ActiveGameEntity
	
	assert(false, "No ActiveGameEntity found")
	return
