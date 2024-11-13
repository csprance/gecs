## Applies to any ball and mutliplys the balls damage
class_name PowerupMegaSystem
extends System

func query():
    return q.with_all([C_MegaBall, C_ActiveBall, C_DamageOutput])

func process(entity, delta):
    var damage_output = entity.get_component(C_DamageOutput) as C_DamageOutput
    var mega_ball = entity.get_component(C_MegaBall) as C_MegaBall

    # Tick the time down each frame
    mega_ball.time -= delta

    # apply the mega ball damage to the damage output value
    if mega_ball.original_damage == 0:
        mega_ball.original_damage = damage_output.value
        damage_output.value = mega_ball.damage
    
    # When the time is up remove the component from the ball 
    # and set the damage back to original
    if mega_ball.time <= 0:
        damage_output.value = mega_ball.original_damage
        entity.remove_component(C_MegaBall)
