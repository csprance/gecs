class_name ShootWaterPistolAction
extends Action

@export var e_projectile: PackedScene


func execute() -> void:
    var active_weapon = get_active_weapon()
    var player = get_player()
    if not active_weapon or not player:
        return

    var direction = calculate_direction(player)
    var projectile_transform = create_projectile_transform(player, direction)
    instantiate_projectile(active_weapon, projectile_transform, direction)

# Helper functions

# Retrieves the active weapon entity from the ECS world.
func get_active_weapon():
    var weapons = Queries.active_weapons().execute()
    return weapons[0] if weapons.size() > 0 else null

# Retrieves the player entity from the ECS world.
func get_player():
    var players = Queries.is_players().execute()
    return players[0] if players.size() > 0 else null

# Calculates the shooting direction based on the player's look-at component.
func calculate_direction(player):
    var c_trs = player.get_component(C_Transform) as C_Transform
    var c_lookat = player.get_component(C_LookAt) as C_LookAt
    if not c_trs or not c_lookat:
        return Vector3.ZERO
    # Direction from the player to the look-at target, ignoring the y-axis.
    var dir = (c_lookat.target - c_trs.position).normalized()
    dir.y = 0
    return dir.normalized()

# Creates a transform for the projectile based on the player's position and direction.
func create_projectile_transform(player, direction):
    var c_trs = player.get_component(C_Transform) as C_Transform
    var transform = Transform3D()
    
    # Position the projectile slightly in front of the player.
    transform.origin = c_trs.transform.origin + direction
    
    # Orient the projectile to face the shooting direction.
    transform.basis = Basis.looking_at(direction, Vector3.UP)
    return transform

# Instantiates the projectile entity and initializes its components.
func instantiate_projectile(active_weapon, transform, direction):
    var projectile_entity = e_projectile.instantiate() as Projectile
    if not projectile_entity:
        return null

    # Set up the transform component for the projectile.
    var c_trs = C_Transform.new()
    c_trs.transform = transform

    # Retrieve the projectile component from the active weapon.
    var c_weapon = active_weapon.get_component(C_Weapon) as C_Weapon
    var c_projectile = c_weapon.projectile

    # Add initial components to the projectile entity.
    projectile_entity.add_components([c_trs, c_projectile])

    # Add the projectile entity to the ECS world.
    ECS.world.add_entity(projectile_entity)

    # Set up the velocity component for the projectile.
    var c_velocity = C_Velocity.new()
    c_velocity.speed = c_projectile.speed
    c_velocity.direction = direction

    # Add remaining components after adding to the world.
    projectile_entity.add_components([c_velocity])

    return projectile_entity
