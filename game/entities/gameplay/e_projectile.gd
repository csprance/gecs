class_name Projectile
extends Entity

@onready var comp_area: ComponentArea3D = %ReusableComponentArea

func on_ready():
    # Take the C_Transform and sync it with the transform of the entity
    Utils.sync_from_transform(self)
    # Get the projectile data
    var c_projectile = get_component(C_Projectile) as C_Projectile
    
    # # Set the velocity on the projectile
    # var c_velocity = get_component(C_Velocity) as C_Velocity
    # c_velocity.speed = c_projectile.speed

    # Add what damage we'll doo the component area
    comp_area.body_on_enter = [c_projectile.damage_component]
    
    # Add the projectile visuals
    var projectile_visuals = c_projectile.projectile_visuals.instantiate()
    add_child(projectile_visuals)

    comp_area.entity_entered.connect(_on_hit_entity)

func _on_hit_entity(_e, _p):
    ECS.world.remove_entity(self)