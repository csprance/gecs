class_name LookAtSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_LookAt, C_Transform])

func process(entity: Entity, _delta: float) -> void:
    var c_look_at = entity.get_component(C_LookAt) as C_LookAt
    var c_transform = entity.get_component(C_Transform) as C_Transform

    var position = c_transform.transform.origin
    var direction = c_look_at.target - position
    direction.y = 0
    direction = direction.normalized()

    var rotation_y = atan2(direction.x, direction.z)
    # Update the transform's rotation around the Y-axis
    c_transform.transform.basis = Basis(Vector3.UP, rotation_y)

    # After updating the rotation, add the debug draw
    if c_look_at.debug:
        var aim_from = c_transform.transform.origin
        var aim_at = c_look_at.target
        DebugDraw3D.draw_arrow(aim_from, aim_at, Color.RED, 1.0, true)