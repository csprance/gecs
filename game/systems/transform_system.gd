# The transform system handles all the position, rotation and scale changes
class_name TransformSystem
extends System
	
	
func on_process_entity(entity, delta):
	var transform: Transform = entity.get_component('transform')
	if entity is Node2D:
		entity.position = transform.position
		entity.rotation = transform.rotation
		entity.scale = transform.scale

