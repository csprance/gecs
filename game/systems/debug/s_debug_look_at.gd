    
    
class_name DebugLookAtSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_LookAt, C_Transform])

func process(entity: Entity, _delta: float) -> void:
    var c_look_at = entity.get_component(C_LookAt) as C_LookAt
    if c_look_at.debug:
        var c_transform = entity.get_component(C_Transform) as C_Transform
        var aim_from = c_transform.transform.origin
        var aim_at = c_look_at.target
        
        # DebugDraw3D.draw_arrow(aim_from, aim_at, Color.RED, 1.0, true)