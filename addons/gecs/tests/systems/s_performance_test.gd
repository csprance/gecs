## Simple test system for performance benchmarking
class_name PerformanceTestSystem
extends System


var process_count: int = 0


func query():
	return ECS.world.query.with_all([C_TestA])


func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		process_count += 1
		# Simulate some light processing
		var component = entity.get_component(C_TestA)
		if component:
			# Access component data (simulates typical system work)
			var _value = component.value # Read property directly, not via reflection
	
	
func reset_count():
	process_count = 0
