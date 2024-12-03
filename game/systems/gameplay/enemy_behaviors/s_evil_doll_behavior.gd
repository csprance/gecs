## Evil Dolls wander randomly until they see the player, then they rush at the player choosing a path through them
## They will also attempt to throw a knife at the player randomly if they are in the attack area
class_name EvilDollBehaviorSystem
extends System

# How fast the evil doll moves when it's chasing
const CHASE_SPEED = 2.0
# How fast the evil doll moves when it's bursting
const BURST_SPEED = 5.0
# How fast the evil doll moves when it's interested
const INTERESTED_SPEED = 1.0

@export var c_projectile: C_Projectile

## This has sub systems so we can group all these things together
func sub_systems():
	return [
		## Idle
		[
			ECS.world.query
			.with_all([C_EvilDollBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange])
			.with_none([C_Interested, C_Death])
			.without_relationship([Relationships.chasing_anything()]),
			idle_subsystem
		],
		## Chase
		[
			ECS.world.query
			.with_all([C_EvilDollBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange])
			.with_none([C_Death])
			.with_relationship([Relationships.chasing_anything()]),
			chase_subsystem
		], 
		## Interested
		[
			ECS.world.query
			.with_all([C_EvilDollBehavior, C_Transform, C_Enemy, C_Velocity, C_InterestRange, C_Interested])
			.with_none([C_Death]), 
			interested_subsystem
		],
		## Attack
		[
			ECS.world.query
			.with_all([C_EvilDollBehavior, C_Transform, C_Enemy, C_Velocity])
			.with_none([C_Death, C_AttackCooldown])
			.with_relationship([Relationships.attacking_anything()]), 
			attack_subsystem

		],
		## Ranged Attack
		[
			ECS.world.query
			.with_all([C_EvilDollBehavior, C_Transform, C_Enemy, C_Velocity])
			.with_none([C_Death, C_RangedAttackCooldown])
			.with_relationship([Relationships.range_attacking_anything()]), 
			ranged_attack_subsystem
		],
	]


func ranged_attack_subsystem(entity, _delta):
	# Check if we can attack
	var r_attacking = entity.get_relationship(Relationships.range_attacking_anything())
	var c_trs = r_attacking.target.get_component(C_Transform) as C_Transform
	if not c_trs:
		assert(false, "No transform for ranged attack target")
		return 
	## Look at the target
	entity.add_component(C_LookAt.new(r_attacking.target.get_component(C_Transform).transform.origin + Vector3(0, 1, 0)))
	## Shoot a projectile at the target
	var direction = Utils.calculate_entity_direction(entity)
	var projectile_transform = WeaponUtils.create_projectile_transform(entity, direction)
	WeaponUtils.instantiate_projectile(c_projectile, projectile_transform)
	entity.add_component(C_RangedAttackCooldown.new(randf_range(6.0, 9.0)))

## Try to attack the target	if we can
func attack_subsystem(entity, _delta):
	# look at the player
	var r_attacking = entity.get_relationship(Relationships.attacking_anything())
	Loggie.debug('Attacking', r_attacking.target)
	var c_attacker_trs = r_attacking.target.get_component(C_Transform) as C_Transform
	if c_attacker_trs:
		entity.add_component(C_LookAt.new(c_attacker_trs.transform.origin))
	
	r_attacking.target.add_component(C_Damage.new())
	entity.add_component(C_AttackCooldown.new(randf_range(6.0, 9.0)))


func idle_subsystem(entity, delta):
	# Pick a random spot to go to every 5 seconds
	var t_state = GameState.use_state(entity, 'idle_timer', randf_range(0, 3))
	t_state.value -= delta
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
		c_velocity.direction = Vector3.ZERO
		c_velocity.speed = 0
		return
	
	# Set the velocity to go towards the target
	c_velocity.direction = (c_interested.target - c_trs.transform.origin).normalized()
	c_velocity.speed = INTERESTED_SPEED

func chase_subsystem(entity, _delta):
	# We can't be chasing and interested at the same time
	entity.remove_component(C_Interested)
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	var c_trs = entity.get_component(C_Transform) as C_Transform
	var r_chasing = entity.get_relationship(Relationships.chasing_anything())

	var chase_target = r_chasing.target
	var chase_target_trs = (chase_target.get_component(C_Transform) as C_Transform).transform

	# Set the velocity to go towards the target
	c_velocity.direction = (chase_target_trs.origin - c_trs.transform.origin).normalized()
	c_velocity.speed = CHASE_SPEED

	# Look at the chase target
	var c_look_at = C_LookAt.new(chase_target_trs.origin)
	entity.add_component(c_look_at)
