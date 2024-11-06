## BounceSystem.[br]
## Processes entities that can bounce off surfaces.[br]
## Handles the bouncing logic by modifying the entity's [Velocity] based on the [Bounced] [member Bounced.normal].[br]
## Removes the [Bounced] component after processing.
class_name BounceSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([Transform, Velocity, Bouncable, Bounced])


func process(entity: Entity, _d: float):
	# Get our bounce and velocity component
	var bouncable  = entity.get_component(Bouncable) as Bouncable
	var bounced = entity.get_component(Bounced) as Bounced

	# If it should bounce
	if bouncable.should_bounce:
		# Get the velocity component and modify it
		var velocity = entity.get_component(Velocity) as Velocity
		# Reflect the velocity direction over the normal
		velocity.direction = velocity.direction.bounce(
			bounced.normal
		)
		SoundManager.play('fx', 'bounce')
	
	# Remove the bounced Component because it's only a one time thing
	entity.remove_component(Bounced)

