class_name BounceSystem
extends System

func _init():
	required_components = [Transform, Velocity, Bounce, Bounced]


func process(entity: Entity, delta: float):
	# Get our bounce and velocity component
	var bounce  = entity.get_component(Bounce) as Bounce
	var bounced = entity.get_component(Bounced) as Bounced

	# If it should bounce
	if bounce.should_bounce:
		# Get the velocity component and modify it
		var velocity = entity.get_component(Velocity) as Velocity
		# Reflect the velocity direction over the normal
		velocity.direction = velocity.direction.bounce(
			bounced.normal
		)

	# remove the bounced Component because it's only a one time thing
	entity.remove_component(Bounced)

