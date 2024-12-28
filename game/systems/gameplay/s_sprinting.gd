class_name SprintingSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Sprinting, C_Velocity, C_Movement]).with_none([C_Death, C_SprintCooldown])

func process(entity: Entity, delta: float):
	var c_sprinting = entity.get_component(C_Sprinting) as C_Sprinting
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	var c_movement = entity.get_component(C_Movement) as C_Movement
	
	# Initialize sprint VFX if just starting
	if c_sprinting.timer == 0.0:
		entity._state['sprint_vfx'] = c_sprinting.vfx.instantiate()
		entity.add_child(entity._state['sprint_vfx'])

	if c_movement.direction != Vector3.ZERO:
		c_velocity.velocity = c_velocity.velocity.normalized() * c_movement.speed * c_sprinting.speed_mult
		
	# Update timer and check for completion
	c_sprinting.timer += delta
	if c_sprinting.timer >= c_sprinting.duration:
		# Cleanup and apply cooldown
		if entity._state.has('sprint_vfx'):
			entity.remove_child(entity._state['sprint_vfx'])
			entity._state.erase('sprint_vfx')
		entity.remove_component(C_Sprinting)
		entity.add_component(C_SprintCooldown.new(c_sprinting.cooldown))
