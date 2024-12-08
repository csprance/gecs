class_name SprintingSystem
extends System


func query() -> QueryBuilder:
    return q.with_all([C_Sprinting, C_Velocity]).with_none([C_Death, C_SprintCooldown])

func process(entity: Entity, delta: float):
    var c_sprinting = entity.get_component(C_Sprinting) as C_Sprinting
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    
    if c_sprinting.timer == 0.0:
        c_sprinting.original_speed = c_velocity.velocity.length()
    
    c_velocity.velocity = c_velocity.velocity.normalized() * (c_sprinting.original_speed * c_sprinting.speed_mult)
    
    c_sprinting.timer += delta
    
    # End dash when duration is up
    if c_sprinting.timer >= c_sprinting.duration:
        c_velocity.velocity = c_velocity.velocity.normalized() * c_sprinting.original_speed
        entity.remove_component(C_Dashing)
        entity.add_component(C_DashCooldown.new(c_sprinting.cooldown))
