class_name SPhysics
extends System

# Remember: Systems contain the meat and potatos of everything and can delete
# themselves or add other systems etc. System order matters.

func query() -> QueryBuilder:
	# process_empty = false # Do we want this to run every frame even with no entities?
	return q.with_all([CVelocity, CPosition]) # return the query here
	

func process(entity: Entity, delta: float) -> void:
	var c_position = entity.get_component(CPosition) as CPosition
	var c_velocity = entity.get_component(CVelocity) as CVelocity
	
	c_position.position += c_velocity.velocity.normalized() * delta * c_velocity.speed
