class_name GravitySystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Gravity, C_Velocity])

func process_all(entities, delta):
    var velocitys = ECS.get_components(entities, C_Velocity) as Array[C_Velocity]
    var gravities = ECS.get_components(entities, C_Gravity) as Array[C_Gravity]
    for i in range(entities.size()):
        # apply gravity
        velocitys[i].velocity += gravities[i].gravity * delta
