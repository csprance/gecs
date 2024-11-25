class_name ShootWaterPistolAction
extends Action

@export var e_projectile: PackedScene


func execute() -> void:
    # Get the active weapon and player
    var active_weapon = Queries.active_weapons().execute()[0]
    var player = Queries.is_players().execute()[0]

    # Get the player's transform and look-at target
    var player_c_trs = player.get_component(C_Transform) as C_Transform
    var c_lookat = player.get_component(C_LookAt) as C_LookAt

    # Calculate direction from player to target
    var direction = (c_lookat.target - player_c_trs.position).normalized()

    # Create a new transform for the projectile
    var projectile_transform = Transform3D()
    projectile_transform.origin = player_c_trs.transform.origin + direction
    projectile_transform.basis = Basis().looking_at(direction, Vector3.UP)

    # Instantiate projectile entity and add components
    var projectile_entity = e_projectile.instantiate() as Projectile
    var c_trs = C_Transform.new()
    c_trs.transform = projectile_transform
    var c_weapon = active_weapon.get_component(C_Weapon) as C_Weapon
    var c_projectile = c_weapon.projectile
    var c_velocity = C_Velocity.new()
    c_velocity.speed = c_projectile.speed
    c_velocity.direction = direction
    projectile_entity.add_components([c_trs, c_projectile])

    # Add the projectile entity to the ECS world
    ECS.world.add_entity(projectile_entity)
    projectile_entity.add_components([c_trs, c_projectile, c_velocity])
