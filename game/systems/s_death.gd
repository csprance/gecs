class_name DeathSystem
extends System

func query(q: QueryBuilder) -> QueryBuilder:
    return q.with_all([Death]) # add required components


func process(entity: Entity, delta: float) -> void:
    Loggie.debug('Death!', self)
    SoundManager.play('fx', 'kill')
    
    var game_state_ents = ECS.buildQuery().with_all([GameState]).execute()
    for game_state_ent in game_state_ents:
        var reward = Reward.new()
        reward.points = 10
        game_state_ent.add_component(reward)
        var game_state = game_state_ent.get_component(GameState) as GameState
        game_state.blocks -= 1


    ECS.world.remove_entity(entity)


