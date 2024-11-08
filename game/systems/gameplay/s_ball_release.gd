class_name BallReleaseSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Captured, C_ActiveBall])


func process(entity: Entity, _d: float) -> void:
	if Input.is_action_just_pressed('paddle_bump'):
		# We know it's a ball
		var ball = entity as Ball
		# Create a new velocity that uses the balls default speed
		var velocity = C_Velocity.new()
		velocity.speed = ball.ball_speed
		velocity.direction = Vector2.UP
		# remove our captured component
		ball.remove_component(C_Captured)
		# Add those components in and send it on it's way
		ball.add_components([velocity, C_Friction.new()])
