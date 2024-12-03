class_name VictimSystem
extends System

func sub_systems():
    return [
        [ECS.world.query.with_all([C_Victim, C_Death]), victim_death_subsys],
        [ECS.world.query.with_all([C_Victim, C_Saved]), victim_saved_subsys],
    ]

func victim_death_subsys(entity, _delta: float):
    GameState.victims -= 1
    entity.add_component(C_IsPendingDelete.new())

func victim_saved_subsys(entity, _delta: float):
    entity.add_component(C_IsPendingDelete.new())

