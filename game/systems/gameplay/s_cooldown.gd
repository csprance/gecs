# Manages cooldowns of different types for entities together
class_name CooldownSystem
extends System

var coooldown_components = [C_AttackCooldown, C_RangedAttackCooldown]

func query() -> QueryBuilder:
    return q.with_all(coooldown_components)


func process(entity: Entity, delta: float):
    for component in coooldown_components:
        if entity.has_component(component):
            update_cooldown(entity.get_component(component), entity, delta)


func update_cooldown(cooldown: Component, entity: Entity, delta: float):
    cooldown.time -= delta
    if cooldown.time <= 0:
        # remove_component takes the class type not the instance so get that
        entity.remove_component(cooldown.get_script())
