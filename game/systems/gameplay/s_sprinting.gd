class_name SprintingSystem
extends System


func query() -> QueryBuilder:
    return q.with_all([C_Sprinting, C_Velocity]).with_none([C_Death, C_SprintCooldown])

func process(entity: Entity, delta: float):
    var c_sprinting = entity.get_component(C_Sprinting) as C_Sprinting
    var c_velocity = entity.get_component(C_Velocity) as C_Velocity
    
    c_velocity.velocity *= c_sprinting.speed_mult
    
    c_sprinting.timer += delta
    
    # End dash when duration is up
    if c_sprinting.timer >= c_sprinting.duration:
        entity.remove_component(C_Sprinting)
        entity.add_component(C_SprintCooldown.new(c_sprinting.cooldown))
