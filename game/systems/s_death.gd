class_name DeathSystem
extends System

func query() -> QueryBuilder:
	return q.with_any([C_Death]) # add required components


func process(entity: Entity, _delta: float) -> void:
	Loggie.debug('Death!', self)
	SoundManager.play('fx', 'kill')
	
	# Add a reward to the game state
	var game_state_ent = GameStateUtils.get_active_game_state_entity()
	var reward = C_Reward.new()
	reward.points = 10
	game_state_ent.add_component(reward)
	
	# Get the Game State Component
	var game_state = game_state_ent.get_component(C_GameState) as C_GameState
	game_state.blocks -= 1


	ECS.world.remove_entity(entity)


