
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
	WeaponUtils.instantiate_projectile(c_projectile, projectile_transform)
	var c_play_anim = C_PlayAnimation.new("player/shoot")
	c_play_anim.callback = func (): player.add_component(C_PlayAnimation.new("player/idle", 1, true))
	player.add_component(c_play_anim)
	# remove one ammo from the active weapon
	InventoryUtils.remove_inventory_item(active_weapon)
	GameState.weapon_fired.emit(active_weapon)
