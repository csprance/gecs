class_name EventSystem
extends System

func query():
    return q.with_all([C_Event])

func process(_entity, _delta: float):
    pass
