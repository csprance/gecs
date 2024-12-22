## CharacterBody3DSystem.
## Moves the entity around using the CharacterBody3D System
class_name CharacterBody3DSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_CharacterBody3D, C_Transform]).with_none([C_Projectile])

func process_all(entities, _delta: float):
	var c_velocitys = ECS.get_components(entities, C_Velocity) as Array[C_Velocity]
	var c_trss = ECS.get_components(entities, C_Transform) as Array[C_Transform]
	for i in range(entities.size()):
		assert(entities[i] is CharacterBody3D, 'Entity is not a CharacterBody3D. Check its components')
		if not entities[i] is CharacterBody3D:
			continue # skip if it's not a character body
		# Set the velocity from the velocity component
		entities[i].velocity = c_velocitys[i].velocity
		# Move the entity
		if entities[i].move_and_slide():
			pass
			# Check if we're on the floor and ignore the floor collisions
			# if not entities[i].is_on_floor():
			# 	pass
				# # Add a collision event to the entity that just collided to handle collisions
				# var c_collision = C_Collision.new()
				# var col = entities[i].get_last_slide_collision()
				# c_collision.collision = col
				# entities[i].add_component(c_collision)
		# Set the velocity from the entity to the component
		c_velocitys[i].velocity = entities[i].velocity
		# Sync the transform back to the entity
		c_trss[i].transform = entities[i].global_transform
		
