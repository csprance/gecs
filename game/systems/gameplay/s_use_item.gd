class_name UseItemSystem
extends System

func query():
    return q.with_all([C_UsingItems]).with_none([C_Death])

func process(_entity, _delta: float):
    pass
