
## Handles collisions with the paddle.
class_name PaddleCollisionSystem
extends System

func query():
	return q.with_all([C_PaddleCollision, C_Transform])

func process(entity, _delta):
	var collision = entity.get_component(C_PaddleCollision).collision
	var collider = collision.get_collider()
	var entity_trs = entity.get_component(C_Transform)
	var paddle_trs = collider.get_component(C_Transform)
	
	# Check if the paddle has the capture power-up
	if collider.get_component(C_CaptureNextBall):
		# Add C_Captured to the ball
		var c_captured = C_Captured.new()
		# Calculate the offset between the paddle and the ball
		c_captured.offset = entity_trs.position - paddle_trs.position
		entity.add_component(c_captured)
		# Remove movement components from the ball
		collider.remove_components([C_CaptureNextBall])
	else:
		# The thing that collides bounces off the collider surface
		var c_bounced = C_Bounced.new()
		c_bounced.normal = collision.get_normal()
		var half_width = collider.paddle_width / 2.0
		var max_rot_rad = deg_to_rad(collider.max_rot)
		var theta = remap(entity_trs.position.x - paddle_trs.position.x, -half_width, half_width, -max_rot_rad, max_rot_rad)

		# Rotate the normal vector by the calculated angle
		collider.last_normal = collision.get_normal().rotated(theta).normalized()
		c_bounced.normal = collider.last_normal
		entity.add_component(c_bounced)
	
	entity.remove_component(C_PaddleCollision)
