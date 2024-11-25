class_name Projectile
extends Entity

func on_ready():
    Utils.sync_from_transform(self)
    var c_projectile = get_component(C_Projectile) as C_Projectile
    var c_velocity = get_component(C_Velocity) as C_Velocity
    c_velocity.speed = c_projectile.speed
    
    var projectile_visuals = c_projectile.projectile_visuals.instantiate()
    add_child(projectile_visuals)