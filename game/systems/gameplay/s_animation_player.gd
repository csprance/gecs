## This system is responsible for playing animations on the player entity
class_name AnimationPlayerSystem
extends System

func query():
    return q.with_all([C_AnimationPlayer, C_PlayAnimation])

func process(entity: Entity, delta: float) -> void:
    var c_play_animation = entity.get_component(C_PlayAnimation) as C_PlayAnimation
    if c_play_animation.time == 0.0:
        var c_anim_player: C_AnimationPlayer = entity.get_component(C_AnimationPlayer)
        var anim_player = entity.get_node(c_anim_player.player) as AnimationPlayer
        anim_player.play(c_play_animation.anim_name, c_play_animation.time)

    c_play_animation.time += delta * c_play_animation.anim_speed
    
    if c_play_animation.time >= 1.0:
        c_play_animation.finished = true
        c_play_animation.time = 0.0
        if c_play_animation.callback:
            c_play_animation.callback.call()
        if not c_play_animation.loop:
            entity.remove_component(C_PlayAnimation)