class_name _CLASS_
extends System

# Remember: Systems contain the meat and potatos of everything and can delete
# themselves or add other systems etc. System order matters.

func query(q: QueryBuilder) -> QueryBuilder:
	return q.with_all([]) # add required components
	# process_empty = false # Do we want this to run every frame even with no entities?


func process(entity: Entity, delta: float) -> void:
	pass # code here....
