class_name TrampolineControlsSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_TrampolineControls, C_Player]).with_relationship([Relationship.new(C_BouncingOn, Trampoline)])


func process(entity, delta):
    # Jump in the direction we press a key in
    pass