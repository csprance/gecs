class_name GravitySystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Gravity, C_Velocity])

func process_all(entities, delta):
    var velocitys = ECS.get_components(entities, C_Velocity) as Array[C_Velocity]
    var gravities = ECS.get_components(entities, C_Gravity) as Array[C_Gravity]
    for i in range(entities.size()):
        # combine dir and speed to get velocity
        var velocity_vector = velocitys[i].direction * velocitys[i].speed
        # apply gravity
        velocity_vector += gravities[i].direction * gravities[i].value * delta
        # split it back up
        velocitys[i].speed = velocity_vector.length()
        velocitys[i].direction = velocity_vector.normalized()
