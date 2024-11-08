## Handles the collision components created on entities based on the collision member [KinematicCollision2D].
class_name CollisionSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Collision])


func process(entity, _delta: float):
    var collision = entity.get_component(C_Collision).collision
    var collider = collision.get_collider()

    # Default collision just adds a bounce and other collisons can modify that
    var c_bounced = C_Bounced.new()
    c_bounced.normal = collision.get_normal()
    entity.add_component(c_bounced)

    match collider.get_script():
        Paddle:
            paddle_collision(entity, collider, collision)  
        Bumper:
            bumper_collision(entity, collider, collision)
        Brick:
            brick_collision(entity, collider, collision)
        _:
            Loggie.error("Unknown collider type: ", collider.get_script())
    
    entity.remove_component(C_Collision)

# When things collide with a bumper, they get the components from the bumper
func bumper_collision(entity, collider, _collision):
    # They bounce off the bumper the same
    for comp in collider.components_to_add:
            entity.add_component(comp.duplicate())

# When things collide with a paddle, they bounce off the paddle but based on the center of the paddle
func paddle_collision(entity, collider, collision):
    # The thing that collides bounces off the collider surface
    var c_bounced = C_Bounced.new()
    c_bounced.normal = collision.get_normal()
    var entity_trs = entity.get_component(C_Transform) as C_Transform
    var paddle_trs = collider.get_component(C_Transform) as C_Transform

    # Calculate the delta vector from paddle to ball
    var half_width = collider.paddle_width / 2.0
    var max_rot_rad = deg_to_rad(collider.max_rot)
    var delta = remap(entity_trs.position.x - paddle_trs.position.x, -half_width, half_width, -max_rot_rad, max_rot_rad)

    # Rotate the normal vector by the calculated angle
    collider.last_normal = collision.get_normal().rotated(delta)
    c_bounced.normal = collider.last_normal
    entity.add_component(c_bounced)

func brick_collision(_entity, collider, _collision):
    # The thing we collided with takes damage
    collider.add_component(C_Damage.new())