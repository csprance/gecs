class_name ShootActiveWeaponAction
extends Action


func execute(_e) -> void:
    var active_weapon = GameState.active_weapon
    var player = GameState.player
    if not active_weapon or not player:
        return

    var direction = Utils.calculate_entity_direction(player)
    var projectile_transform = WeaponUtils.create_projectile_transform(player, direction)
        # Retrieve the projectile component from the active weapon.
    var c_projectile = WeaponUtils.get_projectile_component(active_weapon)
    WeaponUtils.instantiate_projectile(c_projectile, projectile_transform)
