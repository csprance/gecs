class_name TestBSystem
extends System

func query():
    return q.with_all([C_TestA])

func process(entity: Entity, delta: float):
    var a = entity.get_component(C_TestA)
    a.value += 1
    print("TestBSystem: ", a.value)