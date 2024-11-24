class_name CooldownSystem
extends System


func query() -> QueryBuilder:
    return q.with_all([C_AttackCooldown])


func process(entity: Entity, delta: float):
    var cooldown = entity.get_component(C_AttackCooldown) as C_AttackCooldown
    cooldown.time -= delta
    if cooldown.time <= 0:
        entity.remove_component(C_AttackCooldown)
