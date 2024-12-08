class_name ShootActiveWeaponAction
extends Action


func _action(_e) -> void:
    var active_weapon = GameState.active_weapon
    var player = GameState.player
    if not active_weapon or not player:
        return

    var c_qty = active_weapon.get_component(C_Quantity) as C_Quantity
    if c_qty:
        c_qty.value -= 1
        if c_qty.value == 0:
            InventoryUtils.remove_inventory_item(active_weapon)
            return

    var direction = Utils.calculate_entity_direction(player)
    var projectile_transform = WeaponUtils.create_projectile_transform(player, direction)
        # Retrieve the projectile component from the active weapon.
    var c_projectile = WeaponUtils.get_projectile_component(active_weapon)
    WeaponUtils.instantiate_projectile(c_projectile, projectile_transform)

    GameState.weapon_fired.emit(active_weapon)
