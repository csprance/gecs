class_name BallReleaseSystem
extends System

var ball: Ball

func _init():
	required_components = [Captured, ActiveBall] # add required components

func process(entity: Entity, delta: float) -> void:
	if Input.is_action_just_pressed('paddle_bump'):
		# We know it's a ball
		ball = entity
		# remove our captured component
		ball.remove_component(Captured)
		# Create a new velocity that uses the balls default speed
		var velocity = Velocity.new()
		velocity.speed = ball.ball_speed
		velocity.direction = Vector2.UP
		# Add those components in and send it on it's way
		ball.add_components([velocity, Friction.new()])
