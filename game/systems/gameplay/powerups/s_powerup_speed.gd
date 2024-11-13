## The Powerup System runs for any entity that has a Velocity and Speed Modifier on it
## and it apply the speed multiplier to velocity.
class_name PowerupSpeedSystem
extends System

func query():
    return q.with_all([C_SpeedModifier, C_Velocity])

func process(entity, delta):
    var speed = entity.get_component(C_SpeedModifier) as C_SpeedModifier
    var velocity = entity.get_component(C_Velocity) as C_Velocity
    
    # store our original time so we can restore it later
    if speed.original_speed == 0.0:
        speed.original_speed = velocity.speed
        velocity.speed = speed.original_speed * speed.multiplier

    # Tick the time down
    speed.time -= delta
    
    # Remove the component when time is up
    if speed.time <= 0:
        velocity.speed = speed.original_speed
        entity.remove_component(C_SpeedModifier)
