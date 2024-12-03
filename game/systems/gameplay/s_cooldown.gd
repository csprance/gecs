# Manages cooldowns of different types for entities together
class_name CooldownSystem
extends System

var coooldown_components: Array = [C_AttackCooldown, C_RangedAttackCooldown]

func query() -> QueryBuilder:
    return q.with_any(coooldown_components)


func process(entity: Entity, delta: float):
    for component in coooldown_components:
        if entity.has_component(component):
            var c_cooldown = entity.get_component(component)
            c_cooldown.time -= delta
            if c_cooldown.time <= 0:
                # remove_component takes the class type not the instance so get that
                entity.remove_component(component)
