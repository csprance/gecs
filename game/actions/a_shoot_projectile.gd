
class_name ShootProjectileAction
extends Action

func _meta():
    return {
        'name': "Shoot Projectile",
        'description': "Shoots a projectile based on the passed in metdata of [Weapon,Shooter].",
    }

func _action(_e) -> void:
    print(meta)
    var active_weapon = meta.get('item') as Entity
    var player = meta.get('player') as Entity
    if not active_weapon or not player:
        return

    # Decrease the quantity of the active weapon.
    var c_qty = active_weapon.get_component(C_Quantity) as C_Quantity
    if c_qty:
        c_qty.value -= 1
        #
        if c_qty.value == 0:
            InventoryUtils.remove_inventory_item(active_weapon)

    var direction = Utils.calculate_entity_direction(player)
    var projectile_transform = WeaponUtils.create_projectile_transform(player, direction)
        # Retrieve the projectile component from the active weapon.
    var c_projectile = WeaponUtils.get_projectile_component(active_weapon)
    WeaponUtils.instantiate_projectile(c_projectile, projectile_transform)
    var c_play_anim = C_PlayAnimation.new("player/shoot")
    c_play_anim.callback = func (): player.add_component(C_PlayAnimation.new("player/idle", 1, true))
    player.add_component(c_play_anim)

    GameState.weapon_fired.emit(active_weapon)
