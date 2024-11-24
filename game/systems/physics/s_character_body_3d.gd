## CharacterBody3DSystem.
## Moves the entity around using the CharacterBody3D System
class_name CharacterBody3DSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_CharacterBody3D, C_Transform])

func process(entity, _delta: float):
	if entity is CharacterBody3D:
		var velocity = entity.get_component(C_Velocity) as C_Velocity
		# Set the velocity from the velocity component
		entity.velocity = velocity.direction.normalized() * velocity.speed
		# Move the entity
		if entity.move_and_slide():
			# Check if we're on the floor and ignore the floor collisions
			# Add a collision event to the entity that just collided to handle collisions
			var c_collision = C_Collision.new()
			var col = entity.get_last_slide_collision()
			c_collision.collision = col
			entity.add_component(c_collision)
		# Set the velocity from the entity to the component
		velocity.direction = entity.velocity.normalized()
		velocity.speed = entity.velocity.length()
		# Sync the transform back to the entity
		Utils.sync_transform(entity)

