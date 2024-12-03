class_name DashingSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Dashing, C_Velocity]).with_none([C_Death]).without_relationship([Relationship.new(C_Cooldown.new(), ECS.wildcard)])

func process(entity: Entity, delta: float):
    var c_dash = entity.get_component(C_Dashing) as C_Dashing
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    
    if c_dash.timer == 0.0:
        c_dash.original_speed = c_velocity.velocity.length()
    
    c_velocity.velocity = c_velocity.velocity.normalized() * (c_dash.original_speed * c_dash.speed_mult)
    
    c_dash.timer += delta
    
    # End dash when duration is up
    if c_dash.timer >= c_dash.duration:
        c_velocity.velocity = c_velocity.velocity.normalized() * c_dash.original_speed
        entity.remove_component(C_Dashing)
        var dash_cooldown = Entity.new()
        dash_cooldown.add_component(C_Cooldown.new(c_dash.cooldown))
        ECS.world.add_entity(dash_cooldown)
        entity.add_relationship(Relationship.new(C_Cooldown.new(), dash_cooldown))
