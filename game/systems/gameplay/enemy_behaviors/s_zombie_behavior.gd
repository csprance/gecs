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
			ECS.world.query
			.with_all([C_ZombieBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange])
			.with_none([C_Interested, C_Death])
			.without_relationship([Relationships.chasing_anything()]),
			idle_subsystem
		],
		## Chase
		[
			ECS.world.query
			.with_all([C_ZombieBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange])
			.with_none([C_Death])
			.with_relationship([Relationships.chasing_anything()]),
			chase_subsystem
		], 
		## Interested
		[
			ECS.world.query
			.with_all([C_ZombieBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange, C_Interested])
			.with_none([C_Death]), 
			interested_subsystem
		],
		## Attack
		[
			ECS.world.query
			.with_all([C_ZombieBehavior, C_Transform, C_Enemy, C_Velocity])
			.with_none([C_Death, C_AttackCooldown])
			.with_relationship([Relationships.attacking_anything()]), 
			attack_subsystem
		],
	]

## Try to attack the target	if we can
func attack_subsystem(entity, _delta):
	# look at the player
	var r_attacking = entity.get_relationship(Relationships.attacking_anything())
	Loggie.debug('Attacking', r_attacking.target)
	r_attacking.target.add_component(C_Damage.new())
	entity.add_component(C_AttackCooldown.new(1.0))
	var c_attacker_trs = r_attacking.target.get_component(C_Transform) as C_Transform
	if c_attacker_trs:
		entity.add_component(C_LookAt.new(c_attacker_trs.transform.origin))


func idle_subsystem(entity, _delta):
	# Pick a random spot to go to every 5 seconds
	var t_state = GameState.use_state(entity, 'idle_timer', randf_range(0, 3))
	t_state.value -= _delta
	# Pick a random spot to get interested in every 5 seconds
	if t_state.value <= 0:
		# reset the timer
		t_state.value = randf_range(2, 3)
		var c_trs = entity.get_component(C_Transform) as C_Transform
		var c_interested = C_Interested.new(c_trs.transform.origin + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)))
		var c_look_at = C_LookAt.new(c_interested.target)
		entity.add_components([c_interested, c_look_at])


func interested_subsystem(entity, _delta):
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	var c_trs = entity.get_component(C_Transform) as C_Transform
	var c_interested = entity.get_component(C_Interested) as C_Interested
	
	# Check if we're close enough to the target and then idle
	if c_trs.transform.origin.distance_to(c_interested.target) < 0.1:
		entity.remove_component(C_Interested)
		c_velocity.velocity = Vector3.ZERO
		return
	
	# Set the velocity to go towards the target
	c_velocity.velocity = (c_interested.target - c_trs.transform.origin).normalized() * ZOMBIE_SPEED
	

func chase_subsystem(entity, _delta):
	# We can't be chasing and interested at the same time
	entity.remove_component(C_Interested)
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	var c_trs = entity.get_component(C_Transform) as C_Transform
	var r_chasing = entity.get_relationship(Relationships.chasing_anything())

	var chase_target = r_chasing.target
	var chase_target_trs = (chase_target.get_component(C_Transform) as C_Transform).transform

	# Set the velocity to go towards the target
	c_velocity.velocity = (chase_target_trs.origin - c_trs.transform.origin).normalized() * ZOMBIE_SPEED

	# Look at the chase target
	var c_look_at = C_LookAt.new(chase_target_trs.origin)
	entity.add_component(c_look_at)
	
