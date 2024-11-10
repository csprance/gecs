## PhysicsSystem.(Simple Physics)
##
## Updates entities' positions based on their velocity.
## Processes entities with `Velocity` and `Transform` components.
## Calculates movement and updates the `Transform` component.
class_name PhysicsSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Velocity, C_Transform, C_Physics]).with_none([C_CharacterBody2D])


func process(entity: Entity, delta: float):
    var velocity: C_Velocity   = entity.get_component(C_Velocity)
    var transform: C_Transform = entity.get_component(C_Transform)
    var rot_vel = entity.get_component(C_Rotvel) as C_Rotvel
    # Normalize direction to prevent speed inconsistencies
    transform.position += velocity.direction.normalized() * velocity.speed * delta
    if rot_vel:
        transform.rotation += rot_vel.angular_velocity * delta
