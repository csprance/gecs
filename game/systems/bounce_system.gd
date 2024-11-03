class_name BounceSystem
extends System

func _init():
	required_components = [Transform, Velocity, Bounce]

func process(entity : Entity, delta: float):
	# Get our bounce and velocity component
	var bounce_component: Bounce = entity.get_component(Bounce)
	# If it should bounce
	if bounce_component.should_bounce:
		# Get the velocity componet and modify it
		var velocity_component: Velocity = entity.get_component(Velocity)
		# Take the direction from the bounce component
		velocity_component.direction = bounce_component.normal
		# TODO: Maybe we do some sort of reduction of speed here?
		# It shoudl stop bouncing on the next frame
		bounce_component.should_bounce = false

