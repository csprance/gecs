class_name SQ_IsPlayer
extends StaticQuery

func query():
    return ECS.world.query.with_all([C_Player])