class_name DashingSystem
extends System


func query() -> QueryBuilder:
    return q.with_all([C_Dashing, C_Velocity]).with_none([C_Death])


func process(entity: Entity, delta: float):
    var c_dash = entity.get_component(C_Dashing) as C_Dashing
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    c_dash.timer += delta
    c_velocity.speed = c_velocity.speed * c_dash.speed_mult

    if c_dash.timer >= c_dash.duration:
        entity.remove_component(C_Dashing)
