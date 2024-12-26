# The ProjectileSystem handles the movement and collision of projectile entities.
# It processes projectiles' travel and interactions with other entities or the environment.
# This system is used within the physics systems to manage all projectile-related behaviors.
class_name ProjectileSystem
extends System

func sub_systems():
	return [
		[
			ECS.world.query
			.with_all([C_Projectile, C_Velocity, C_Transform, C_CharacterBody3D, C_Collision]),
			projectile_collision_subsys
		],
		[
			ECS.world.query.with_all([C_Projectile, C_Velocity, C_Transform, C_CharacterBody3D]),
			travelling_subsys
		],
	]

## Runs as the projectile is travelling through the air
func travelling_subsys(e_projectile, delta: float):
	e_projectile = e_projectile as CharacterBody3D
	var c_velocity = e_projectile.get_component(C_Velocity) as C_Velocity
	# Set the velocity from the velocity component
	e_projectile.velocity = c_velocity.velocity
	# Move the entity and if it collides add a collision
	if e_projectile.move_and_slide():
		var c_collision = C_Collision.new(e_projectile.get_last_slide_collision())
		e_projectile.add_component(c_collision)
	# Sync the transform component with the data from the CharacterBody3D simulation
	Utils.sync_transform(e_projectile)

## We handle all the different things that can happen with a projectile collision and then finally call handle impact
func projectile_collision_subsys(e_projectile, _delta: float):
	var c_projectile = e_projectile.get_component(C_Projectile) as C_Projectile
	var c_collision = e_projectile.get_component(C_Collision) as C_Collision
	var collider = c_collision.collision.get_collider()
	
	# If it's a hitbox damage the parent entity of the hitbox
	if collider is Hitbox3D:
		var hitbox = collider as Hitbox3D
		hitbox.parent.add_component(c_projectile.damage_component)
	
	# If it's an explosive we need to damage all entities within the explosion radius
	if c_projectile.explosive_radius > 0:
		var bodies = e_projectile.explosion_radius.get_overlapping_bodies()
		for body in bodies:
			if body is Hitbox3D:
				body.parent.add_component(c_projectile.damage_component)

	# end of the road if we didn't return we crashed into something and can't move anymore
	_handle_impact(e_projectile, c_projectile, c_collision)

## Spawns the impact effect and removes the projectile entity
func _handle_impact(e_projectile, c_projectile: C_Projectile, c_collision: C_Collision):
	if c_projectile.impact_effect:
		var impact = c_projectile.impact_effect.instantiate()
		impact.global_transform.origin = c_collision.collision.get_position()
		ECS.world.add_entity(impact)
	
	ECS.world.remove_entity(e_projectile)
