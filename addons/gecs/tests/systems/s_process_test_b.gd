# test overriding process()
class_name ProcessTestSystem_B
extends System


var process_count: int = 0

func _init(_process_empty: bool = false):
	process_empty = _process_empty
	

func query():
	return ECS.world.query.with_all([C_TestB])


func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		if entity:
			process_count += 1
			# Simulate some light processing
			var component = entity.get_component(C_TestB)
			if component:
				# Access component data (simulates typical system work)
				var _data = component.serialize()
				# Simulates a task/action execution system, it clears some task-specific
				# components after completing the task for better performance.
				entity.remove_component(C_TestB)
	
func reset_count():
	process_count = 0
