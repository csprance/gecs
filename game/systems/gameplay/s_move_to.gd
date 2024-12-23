# This just moves the entity toward the target position
class_name MoveToSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_MoveTo, C_Transform, C_CharacterBody3D])