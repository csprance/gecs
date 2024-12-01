class_name TrampolineControlsSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_TrampolineControls, C_Player])


func process(entity, delta):
    # Jump in the direction we press a key in
    pass