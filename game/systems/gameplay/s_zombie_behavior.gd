## Zombies sit around doing nothing until they're interested and then then just go start for that target. 
## They don't have any pathfinding or anything, they just go straight for the target
class_name ZombieBehaviorSystem
extends System

const ZOMBIE_SPEED = 2.0


func query():
	return q.with_all([C_ZombieBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange, C_Interested]).with_none([C_Death])

func process(entity, _delta):
	var c_interest = entity.get_component(C_Interested) as C_Interested
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	var c_trs = entity.get_component(C_Transform) as C_Transform

	# Set the velocity to go towards the target
	c_velocity.direction = (c_interest.target - c_trs.transform.origin).normalized()
	c_velocity.speed = ZOMBIE_SPEED

	
