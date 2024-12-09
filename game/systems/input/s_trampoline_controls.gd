class_name TrampolineControlsSystem
extends System

var jumping_on_tramp = Relationship.new(C_BouncingOn.new(), Trampoline)

func query() -> QueryBuilder:
    return q\
    .with_all([C_TrampolineControls, C_Player])\
    .with_relationship([jumping_on_tramp])


func process(entity, delta):
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    # Jump in the direction we press a key in
    if Input.is_action_just_pressed('move_down'):
        entity.add_component(C_CharacterBody3D.new())
        c_velocity.velocity = Vector3(0, -5, -10)
    if Input.is_action_just_pressed('move_up'):
        entity.add_component(C_CharacterBody3D.new())
        c_velocity.velocity = Vector3(0, -5, 10)
    if Input.is_action_just_pressed('move_left'):
        entity.add_component(C_CharacterBody3D.new())
        c_velocity.velocity = Vector3(-10, -5, 0)
    if Input.is_action_just_pressed('move_right'):
        entity.add_component(C_CharacterBody3D.new())
        c_velocity.velocity = Vector3(10, -5, 0)
    