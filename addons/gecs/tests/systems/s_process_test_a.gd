## Simple test system for performance benchmarking
# test batch processing
class_name ProcessTestSystem_A
extends System


var process_count: int = 0

func _init(_process_empty: bool = false):
	process_empty = _process_empty


func query():
	return ECS.world.query.with_all([C_TestA])


# Unified process function for batch processing
func process(entities: Array[Entity], components: Array, delta: float):
	process_count += 1
	var c_test_a_components = ECS.get_components(entities, C_TestA)
	for i in range(entities.size()):
		# Simulate some light processing
		var component = c_test_a_components[i]
		if component:
			# Access component data (simulates typical system work)
			var _data = component.serialize()
			# Simulates a task/action execution system, it clears some task-specific
			# components after completing the task for better performance.
			entities[i].remove_component(C_TestA)
	return true

func reset_count():
	process_count = 0
