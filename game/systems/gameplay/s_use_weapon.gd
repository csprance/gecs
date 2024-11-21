class_name UseItemSystem
extends System

func query():
    return q.with_all([C_Item])

func process(_entity, _delta: float):
    pass
