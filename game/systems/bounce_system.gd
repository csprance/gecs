class_name BounceSystem
extends System

func _init():
	required_components = [Transform, Velocity, Bounce, Bounced]

func process(entity : Entity, delta: float):
	# Get our bounce and velocity component
	var bounce_component: Bounce = entity.get_component(Bounce)
	var bounced_component: Bounced = entity.get_component(Bounced)
	# If it should bounce
	if bounce_component.should_bounce:
		# Get the velocity componet and modify it
		var velocity_component: Velocity = entity.get_component(Velocity)
		# Reflect the velocity direction over the normal
		var incoming_direction = velocity_component.direction.normalized()
		var normal = bounced_component.normal.normalized()
		var reflected_direction = incoming_direction.bounce(normal)
		velocity_component.direction = reflected_direction
	# remove the bounced Component
	entity.remove_component(Bounced)

