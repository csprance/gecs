class_name BulletShootSystem
extends System

# what brick scene should we spawn?
@export var bullet_scene: PackedScene

func query():
    return q.with_all([C_PlayerMovement])


func process(entity: Entity, _delta: float) -> void:
    if Input.is_action_pressed('paddle_bump'):
        # Instantiate a new brick from the preloaded scene
        var bullet_entity = bullet_scene.duplicate(true).instantiate() as Bullet
        ECS.world.add_entity(bullet_entity)
        # Retrieve and update the Transform component of the brick
        (bullet_entity.get_component(C_Transform) as C_Transform).position = entity.get_component(C_Transform).position