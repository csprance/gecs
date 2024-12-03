class_name DashingSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Dashing, C_Velocity]).with_none([C_Death])

func process(entity: Entity, delta: float):
    var c_dash = entity.get_component(C_Dashing) as C_Dashing
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    
    
    # On first frame of dash, store initial direction
    if c_dash.timer == 0:
        c_dash.dash_direction = c_velocity.velocity.normalized()
        if c_dash.dash_direction == Vector3.ZERO:
            # If no initial velocity, dash forward
            c_dash.dash_direction = -entity.transform.basis.z
    
    c_dash.timer += delta
    
    # Apply dash velocity
    c_velocity.velocity = c_dash.dash_direction * c_dash.speed_mult
    
    # End dash when duration is up
    if c_dash.timer >= c_dash.duration:
        entity.remove_component(C_Dashing)
