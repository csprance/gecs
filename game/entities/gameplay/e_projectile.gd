class_name Projectile
extends Entity

@onready var comp_area: ComponentArea3D = %ReusableComponentArea

func on_ready():
    # Take the C_Transform and sync it with the transform of the entity
    Utils.sync_from_transform(self)
    # Get the projectile data
    var c_projectile = get_component(C_Projectile) as C_Projectile
    # Add the projectile visuals
    var projectile_visuals = c_projectile.projectile_visuals.instantiate()
    add_child(projectile_visuals)