class_name UseWeaponSystem
extends System

func query():
    # The entity is attacking and has an active weapon and is not dead
    return q.with_all([C_Attacking, C_HasActiveWeapon]).with_none([C_Death])

func process(_entity, _delta: float):
    pass
