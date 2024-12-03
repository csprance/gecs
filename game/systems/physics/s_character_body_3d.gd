## CharacterBody3DSystem.
## Moves the entity around using the CharacterBody3D System
class_name CharacterBody3DSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_CharacterBody3D, C_Transform]).with_none([C_Projectile])

func process_all(entities, _delta: float):
	var velocitys = ECS.get_components(entities, C_Velocity) as Array[C_Velocity]
	for i in range(entities.size()):
		if not entities[i] is CharacterBody3D:
			continue # skip if it's not a character body
		# Set the velocity from the velocity component
		entities[i].velocity = (velocitys[i].direction.normalized() * velocitys[i].speed) 
		# Move the entity
		if entities[i].move_and_slide():
			# Check if we're on the floor and ignore the floor collisions
			if not entities[i].is_on_floor():
				pass
				# # Add a collision event to the entity that just collided to handle collisions
				# var c_collision = C_Collision.new()
				# var col = entities[i].get_last_slide_collision()
				# c_collision.collision = col
				# entities[i].add_component(c_collision)
		# Set the velocity from the entity to the component
		velocitys[i].direction = entities[i].velocity.normalized()
		velocitys[i].speed = entities[i].velocity.length()
		# Sync the transform back to the entity
		Utils.sync_transform(entities[i])
