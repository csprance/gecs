class_name UseWeaponSystem
extends System

func query():
    return q.with_all([C_Item])

func process(_entity, _delta: float):
    pass
