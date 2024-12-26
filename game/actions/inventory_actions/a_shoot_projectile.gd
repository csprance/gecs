class_name ShootProjectileAction
extends InventoryAction

func _meta():
	return {
		'name': "Shoot Projectile",
		'description': "Shoots a projectile based on the passed in metdata of [Weapon,Shooter].",
	}

func _use_item(active_weapon: Entity, player: Entity) -> void:
	var direction = Utils.calculate_entity_direction(player)
	var projectile_transform = WeaponUtils.create_projectile_transform(player, direction)
		# Retrieve the projectile component from the active weapon.
	var c_projectile = WeaponUtils.get_projectile_component(active_weapon)
	var e_projectile = WeaponUtils.instantiate_projectile(c_projectile, projectile_transform)
	# add the player's velocity to the projectile ( So we can't run into it)
	var projectile_c_vel = e_projectile.get_component(C_Velocity) as C_Velocity
	var player_c_vel = player.get_component(C_Velocity) as C_Velocity
	
	var projectile_dir = projectile_c_vel.velocity.normalized()
	var forward_speed = projectile_dir.dot(player_c_vel.velocity)
	if forward_speed > 0:
		projectile_c_vel.velocity += projectile_dir * (forward_speed * 0.75)

	var c_play_anim = C_PlayAnimation.new("player/shoot")
	c_play_anim.callback = func (): player.add_component(C_PlayAnimation.new("player/idle", 1, true))
	player.add_component(c_play_anim)
	# remove one ammo from the active weapon
	InventoryUtils.remove_inventory_item(active_weapon)
	GameState.weapon_fired.emit(active_weapon)
