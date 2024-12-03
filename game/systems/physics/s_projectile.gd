class_name ProjectileSystem
extends System

func sub_systems():
	return [
		[
			ECS.world.query
			.with_all([C_Projectile, C_Velocity, C_Transform, C_CharacterBody3D, C_Collision]),
			projectile_collision_subsy
		],
		[
			ECS.world.query.with_all([C_Projectile, C_Velocity, C_Transform, C_CharacterBody3D]),
			travelling_subsys
		],
	]

func projectile_collision_subsy(entity, _delta: float):
	var c_projectile = entity.get_component(C_Projectile) as C_Projectile
	var c_collision = entity.get_component(C_Collision) as C_Collision
	var hitbox = c_collision.collision.get_collider()
	if hitbox is Hitbox3D:
		hitbox.parent.add_component(C_Damage.new(c_projectile.damage_component.amount))
		c_projectile.cur_pass_through_hitboxes += 1
	else:
		ECS.world.remove_entity(entity)
		return
	
	if c_projectile.cur_pass_through_hitboxes >= c_projectile.pass_through_hitboxes:
		ECS.world.remove_entity(entity)
	else:
		entity.remove_component(C_Collision)

func travelling_subsys(entity, _delta: float):
	var c_velocity = entity.get_component(C_Velocity) as C_Velocity
	# Set the velocity from the velocity component

	entity.velocity = c_velocity.velocity
	# Move the entity
	if entity.move_and_slide():
		var c_collision = C_Collision.new()
		var col = entity.get_last_slide_collision() as KinematicCollision3D
		var layer = col.get_collider().collision_layer
		Loggie.debug("Projectile hit layer: %s" % layer)
		# Hit the world layer
		if layer == 1:
			ECS.world.remove_entity(entity)
			return

		c_collision.collision = col
		entity.add_component(c_collision)
	# Set the velocity from the entity to the component
	c_velocity.velocity = entity.velocity
	# Sync the transform back to the entity
	Utils.sync_transform(entity)
