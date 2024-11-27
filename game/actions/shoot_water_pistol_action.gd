class_name ShootWaterPistolAction
extends Action



func execute() -> void:
    var active_weapon = GameState.active_weapon
    var player = GameState.player
    if not active_weapon or not player:
        return

    var direction = Utils.calculate_entity_direction(player)
    var projectile_transform = WeaponUtils.create_projectile_transform(player, direction)
    WeaponUtils.instantiate_projectile(active_weapon, projectile_transform)

# Helper functions
