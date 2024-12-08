# Manages cooldowns of different types for entities together
class_name CooldownSystem
extends System

var coooldown_components: Array = [C_AttackCooldown, C_RangedAttackCooldown, C_DashCooldown, C_SprintCooldown]

func sub_systems():
    return [
        [ECS.world.query.with_any(coooldown_components), cooldowns_subsys],
        [ECS.world.query.with_relationship([Relationship.new(C_Cooldown.new(), ECS.wildcard)]), cooldowns_rel_subsys],
        ]


func cooldowns_subsys(entity: Entity, delta: float):
    for component in coooldown_components:
        if entity.has_component(component):
            var c_cooldown = entity.get_component(component)
            c_cooldown.time -= delta
            if c_cooldown.time <= 0:
                # remove_component takes the class type not the instance so get that
                entity.remove_component(component)

func cooldowns_rel_subsys(entity: Entity, delta: float):
    var r_cooldowns = entity.get_relationship(Relationship.new(C_Cooldown.new(), ECS.wildcard), false)
    for r_cooldown in r_cooldowns:
        var c_cooldown = r_cooldown.target.get_component(C_Cooldown)
        c_cooldown.time -= delta
        if c_cooldown.time <= 0:
            entity.remove_relationship(r_cooldown)
            ECS.world.remove_entity(r_cooldown.target)