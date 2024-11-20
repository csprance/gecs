## Handles the collision components created on entities based on the collision member [KinematicCollision3D].
class_name CollisionSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Collision])


func process(entity, _delta: float):
	var collision = entity.get_component(C_Collision).collision
	var collider = collision.get_collider()
	Loggie.debug("Collision Detected: ", collision, entity, collider)
	
	# Add specific collision components
	match collider.get_script():
		_:
			Loggie.error("Unknown collider type: ", collider.get_script())
	
	entity.remove_component(C_Collision)
