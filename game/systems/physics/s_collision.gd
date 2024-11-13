## Handles the collision components created on entities based on the collision member [KinematicCollision2D].
class_name CollisionSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Collision])


func process(entity, _delta: float):
	var collision = entity.get_component(C_Collision).collision
	var collider = collision.get_collider()
	Loggie.debug("Collision Detected: ", collision, entity, collider)
	
	# Ball always bounces off of everything it touches
	var c_bounced = C_Bounced.new()
	c_bounced.normal = collision.get_normal()
	entity.add_component(c_bounced)
	
	# Add specific collision components
	match collider.get_script():
		Paddle:
			var paddle_collision = C_PaddleCollision.new()
			paddle_collision.collision = collision
			entity.add_component(paddle_collision)
		Bumper:
			var bumper_collision = C_BumperCollision.new()
			bumper_collision.collision = collision
			entity.add_component(bumper_collision)
		Brick:
			var brick_collision = C_BrickCollision.new()
			brick_collision.collision = collision
			entity.add_component(brick_collision)
		_:
			Loggie.error("Unknown collider type: ", collider.get_script())
	
	entity.remove_component(C_Collision)
