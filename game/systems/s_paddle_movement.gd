class_name SPaddleMovement
extends System

# Remember: Systems contain the meat and potatos of everything and can delete
# themselves or add other systems etc. System order matters.

func query() -> QueryBuilder:
	# process_empty = false # Do we want this to run every frame even with no entities?
	return q.with_all([CPaddleMovement, CPosition, CVelocity]).with_any([CPlayer1, CPlayer2]) # return the query here
	

func process(entity: Entity, delta: float) -> void:
	var c_velocity =  entity.get_component(CVelocity) as CVelocity
	var c_player1 = entity.get_component(CPlayer1) as CPlayer1
	var c_player2 = entity.get_component(CPlayer2) as CPlayer2
	
	c_velocity.velocity = Vector2.ZERO
	c_velocity.speed = 500.0
	
	if c_player1:
		if Input.is_action_pressed('paddle_1_down'):
			c_velocity.velocity += Vector2.DOWN
		if Input.is_action_pressed('paddle_1_up'):
			c_velocity.velocity += Vector2.UP
	
	if c_player2:
		if Input.is_action_pressed('paddle_2_down'):
			c_velocity.velocity += Vector2.DOWN
		if Input.is_action_pressed('paddle_2_up'):
			c_velocity.velocity += Vector2.UP
