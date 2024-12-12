class_name LookAtSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_LookAt, C_Transform])

func process(entity: Entity, delta: float) -> void:
    var c_look_at = entity.get_component(C_LookAt) as C_LookAt
    var c_transform = entity.get_component(C_Transform) as C_Transform

    var position = c_transform.transform.origin
    var direction = c_look_at.target - position
    direction.y = 0
    direction = direction.normalized()

    var desired_rotation_y = atan2(direction.x, direction.z)
    var current_rotation_y = c_transform.transform.basis.get_euler().y

    var rotation_y = lerp_angle(current_rotation_y, desired_rotation_y, c_look_at.turn_speed * delta)
    c_transform.transform.basis = Basis(Vector3.UP, rotation_y)

