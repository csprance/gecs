class_name SPosition
extends System


func query() -> QueryBuilder:
	# process_empty = false # Do we want this to run every frame even with no entities?
	return q.with_all([CPosition]) # return the query here
	

func process(entity: Entity, delta: float) -> void:
	var c_pos = entity.get_component(CPosition) as CPosition
	entity.global_transform.origin = c_pos.position
