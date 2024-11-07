## CharacterBody2DSystem.
## Moves the entity around using the CharacterBody2D System
class_name CharacterBody2DSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Velocity, C_CharacterBody2D]).with_none([C_Captured])


func process(entity, _delta: float):
    if entity is CharacterBody2D:
        var velocity = entity.get_component(C_Velocity) as C_Velocity
        # Set the velocity from the velocity component
        entity.velocity = velocity.direction.normalized() * velocity.speed
        # Move the entity
        if entity.move_and_slide():
            var collision = entity.get_last_slide_collision()
            var normal = collision.get_normal()
            # Add the Bounced component to the entity
            var c_bounced = C_Bounced.new()
            c_bounced.normal = normal
            entity.add_component(c_bounced)
        # Set the velocity from the entity to the component
        velocity = entity.velocity
        # Sync the transform back to the entity
        Utils.sync_transform(entity)

