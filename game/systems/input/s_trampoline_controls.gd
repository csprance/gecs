class_name TrampolineControlsSystem
extends System

func query() -> QueryBuilder:
    return q\
    .with_all([C_TrampolineControls, C_Player])\
    .with_relationship([Relationship.new(C_BouncingOn.new(), Trampoline)])


func process(entity, delta):
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    # Jump in the direction we press a key in
    if Input.is_action_just_pressed('move_down'):
        c_velocity.velocity = Vector3(0, -5, -1)
    if Input.is_action_just_pressed('move_up'):
        c_velocity.velocity = Vector3(0, -5, 1)
    if Input.is_action_just_pressed('move_left'):
        c_velocity.velocity = Vector3(-1, -5, 0)
    if Input.is_action_just_pressed('move_right'):
        c_velocity.velocity = Vector3(1, -5, 0)
    