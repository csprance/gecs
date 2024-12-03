class_name _CLASS_
extends System

# Remember: Systems contain the meat and potatos of everything and can delete
# themselves or add other systems etc. System order matters.

func query() -> QueryBuilder:
	# process_empty = false # Do we want this to run every frame even with no entities?
	return q.with_all([]) # return the query here
	

func process(entity: Entity, delta: float) -> void:
	pass # code here....

# If you want a sub system setup, uncomment this comment out process and query and fill it in
# func sub_system():
# 	return [
# 		[ECS.world.query.with_all([]), subsys_a],
# 	] # return any sub systems here

# func subsys_a(entity: Entity, delta: float) -> void:
# 	pass # code here....