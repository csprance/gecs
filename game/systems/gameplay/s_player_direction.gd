## PlayerDirectionSystem.
##
## Handles player input and updates the player's direction they are facing.
class_name PlayerDirectionSystem
extends System

const AIM_OFFSET = Vector3(0, 1, 0)

func query() -> QueryBuilder:
    return q.with_all([C_Player, C_PlayerDirection, C_Transform])


func process(entity: Entity, _delta: float) -> void:
    # Get the camera
    var camera = get_viewport().get_camera_3d()
    if not camera:
        return # no camera bail

    # Get the aim point
    var aim_point = ECS.world.query.with_any([C_AimPoint]).execute()[0] as AimPoint
    if not aim_point:
        return # no aim point bail
    
    var player = entity as Player
    var player_transform = (player.get_component(C_Transform) as C_Transform).transform
    var aim_point_screen_position = (aim_point.get_component(C_ScreenPosition) as C_ScreenPosition).position

    var ray_origin = camera.project_ray_origin(aim_point_screen_position)
    var ray_direction = camera.project_ray_normal(aim_point_screen_position)
    var player_y = player_transform.origin.y + AIM_OFFSET.y

    # Calculate t where the ray intersects y = player_y
    var t = (player_y - ray_origin.y) / ray_direction.y
    var aim_at = ray_origin + ray_direction * t

    var aim_from: Vector3 = player_transform.origin + AIM_OFFSET

    # Compute direction in XZ plane
    var direction = aim_at - aim_from
    direction.y = 0

    # Set rotation around Y-axis
    player.visuals.rotation.y = atan2(direction.x, direction.z)

    # Debug draw the direction
    DebugDraw3D.draw_arrow(aim_from, aim_at, Color.RED, 1.0, true)
