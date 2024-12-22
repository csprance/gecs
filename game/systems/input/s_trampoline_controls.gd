class_name TrampolineControlsSystem
extends System

var jumping_on_tramp = Relationship.new(C_BouncingOn.new(), Trampoline)

func query() -> QueryBuilder:
	return q\
	.with_all([C_TrampolineControls, C_Player])\
	.with_relationship([jumping_on_tramp])


func process(entity, delta):
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	var moved = false
	# Jump in the direction we press a key in
	if Input.is_action_just_pressed('move_down'):
		moved = true
		c_velocity.velocity = Vector3(0, 1, 1)
	if Input.is_action_just_pressed('move_up'):
		moved = true
		c_velocity.velocity = Vector3(0, 1, -1)
	if Input.is_action_just_pressed('move_left'):
		moved = true
		c_velocity.velocity = Vector3(-1, 1, 0)
	if Input.is_action_just_pressed('move_right'):
		moved = true
		c_velocity.velocity = Vector3(1, 1, 0)
	
	if moved:
		entity.add_component(C_CharacterBody3D.new())
		entity.add_component(C_Gravity.new())
		c_velocity.velocity *= 35.0
		c_velocity.velocity.y *= .5
		# c_velocity.velocity.y *= .1
		# remove controls and relationship to trampoline
		entity.remove_component(C_TrampolineControls)
		entity.remove_relationship(Relationship.new(C_BouncingOn.new(), ECS.wildcard))
		# add player movement control back
		entity.add_component(C_Movement.new())
