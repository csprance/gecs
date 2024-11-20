## PlayerDirectionSystem.
##
## Handles player input and updates the player's direction they are facing.
class_name PlayerDirectionSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Player, C_PlayerDirection, C_Transform])


func process(entity: Entity, _delta: float) -> void:
    var player = entity as Player
    var aim_point = ECS.world.query.with_any([C_AimPoint]).execute()[0] as AimPoint
    if not aim_point:
        return
    var transform = player.get_component(C_Transform) as C_Transform
    var aim_point_position = aim_point.get_component(C_ScreenPosition) as C_ScreenPosition
    var camera = get_viewport().get_camera_3d()
    if not camera:
        return

    var from: Vector2 = camera.unproject_position(transform.position)
    var to: Vector2 = aim_point_position.position
    var direction = (from - to).normalized()
    player.rotation = Vector3(direction.x, 0, direction.y)
