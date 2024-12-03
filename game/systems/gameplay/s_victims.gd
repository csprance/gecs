class_name VictimSystem
extends System

func sub_systems():
    return [
        [ECS.world.query.with_all([C_Victim, C_Death]), victim_death_subsy],
        [ECS.world.query.with_all([C_Victim, C_Saved]), victim_saved_subsy],
    ]

func victim_death_subsy(entity, _delta: float):
    pass

func victim_saved_subsy(entity, _delta: float):
    pass

