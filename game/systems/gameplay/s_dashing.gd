class_name DashingSystem
extends System


func query() -> QueryBuilder:
    return q.with_all([C_Dashing, C_Velocity]).with_none([C_Death, C_DashCooldown])

func process(entity: Entity, delta: float):
    var c_dash = entity.get_component(C_Dashing) as C_Dashing
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity

    # Move entity
    c_velocity.velocity = c_dash.velocity
      
    c_dash.timer += delta
    
    # End dash when duration is up
    if c_dash.timer >= c_dash.duration:
        c_velocity.velocity = Vector3.ZERO
        entity.remove_component(C_Dashing)
        entity.add_component(C_DashCooldown.new(c_dash.cooldown))
