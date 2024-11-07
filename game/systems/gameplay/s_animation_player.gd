## This system is responsible for playing animations on the player entity
class_name AnimationPlayerSystem
extends System

func query():
    return q.with_all([C_AnimationPlayer])

func process(entity: Entity, delta: float) -> void:
    pass