## Zombies sit around doing nothing until they're interested and then then just go start for that target. 
## They don't have any pathfinding or anything, they just go straight for the target
class_name ZombieBehaviorSystem
extends System

const ZOMBIE_SPEED = 2.0

## This has sub systems so we can group all these things together
func sub_systems():
	return [
		## Idle
		[
			q.with_all([C_ZombieBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange]).with_none([C_Chasing, C_Interested, C_Death]).as_query_array(),
			idle_subsystem
		],
		## Chase
		[
			q.with_all([C_ZombieBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange]).with_any([C_Chasing, C_Interested]).with_none([C_Death]).as_query_array(), 
			chase_subsystem
		]
	]

func idle_subsystem(entity, _delta):
	# Pick a random spot to go to every 5 seconds
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	c_velocity.speed = 0
	c_velocity.direction = Vector3.ZERO

func chase_subsystem(entity, _delta):
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	var c_trs = entity.get_component(C_Transform) as C_Transform
	
	# Where we want to move towards
	var target = Vector3.ZERO
	
	# If we're chasing
	var c_chasing = entity.get_component(C_Chasing) as C_Chasing
	if c_chasing:
		var chase_target = c_chasing.target
		var chase_target_trs = (chase_target.get_component(C_Transform) as C_Transform).transform
		target = chase_target_trs.origin

	# If we're interested
	var c_interested = entity.get_component(C_Interested) as C_Interested
	if c_interested:
		target = c_interested.target

	# Set the velocity to go towards the target
	c_velocity.direction = (target - c_trs.transform.origin).normalized()
	c_velocity.speed = ZOMBIE_SPEED
	
