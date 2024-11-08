## BounceSystem.[br]
## Processes entities that can bounce off surfaces.[br]
## Handles the bouncing logic by modifying the entity's [Velocity] based on the [Bounced] [member Bounced.normal].[br]
## Removes the [Bounced] component after processing.
class_name BounceSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Transform, C_Velocity, C_Bouncable, C_Bounced])


func process(entity: Entity, _d: float):
    # Get our bounce and velocity component
    var bouncable  = entity.get_component(C_Bouncable) as C_Bouncable
    var bounced = entity.get_component(C_Bounced) as C_Bounced

    # If it should bounce
    if bouncable.should_bounce:
        # Get the velocity component and modify it
        var velocity = entity.get_component(C_Velocity) as C_Velocity
        # Reflect the velocity direction over the normal
        velocity.direction = velocity.direction.bounce(
            bounced.normal
        ).normalized()

        # Reposition the ball to prevent overlapping
        var transform = entity.get_component(C_Transform) as C_Transform
        transform.position += bounced.normal * 5  # Adjust the multiplier as needed
        
        Loggie.debug("Bounce detected. New velocity direction: ", velocity.direction)
        SoundManager.play('fx', 'bounce')
    
    # Remove the bounced Component because it's only a one time thing
    entity.remove_component(C_Bounced)

