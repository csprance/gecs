## Handles collisions with bricks.
class_name BumperCollisionSystem
extends System

func query():
	return q.with_all([C_BumperCollision])

func process(entity, _delta):
	var bumper_collision = entity.get_component(C_BumperCollision).collision
	var collider = bumper_collision.get_collider()
	
	# They bounce off the bumper the same
	for comp in collider.components_to_add:
			entity.add_component(comp.duplicate())
	
	entity.remove_component(C_BumperCollision)
