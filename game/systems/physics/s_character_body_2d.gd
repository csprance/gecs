## CharacterBody2DSystem.
## Moves the entity around using the CharacterBody2D System
class_name CharacterBody2DSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_CharacterBody2D, C_Transform]).with_none([C_Captured])


func process(entity, delta: float):
	if entity is CharacterBody2D:
		var velocity = entity.get_component(C_Velocity) as C_Velocity
		var rot_vel = entity.get_component(C_Rotvel) as C_Rotvel
		var transform = entity.get_component(C_Transform) as C_Transform
		# Set the velocity from the velocity component
		entity.velocity = velocity.direction.normalized() * velocity.speed
		# Move the entity
		if entity.move_and_slide():
			# Add a collision event to the entity that just collided to handle collisions
			var c_collision = C_Collision.new()
			c_collision.collision = entity.get_last_slide_collision()
			entity.add_component(c_collision)
		# Set the velocity from the entity to the component
		velocity = entity.velocity
		# Sync the transform back to the entity
		Utils.sync_transform(entity)
		# Update rotation based on angular velocity
		if rot_vel:
			transform.rotation += rot_vel.angular_velocity * delta

