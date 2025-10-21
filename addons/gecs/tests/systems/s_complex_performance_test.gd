## Complex test system for performance benchmarking
class_name ComplexPerformanceTestSystem
extends System


var process_count: int = 0


func query():
	return ECS.world.query.with_all([C_TestA, C_TestB])


func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		process_count += 1
		# Simulate more complex processing
		var comp_a = entity.get_component(C_TestA)
		var comp_b = entity.get_component(C_TestB)
	
		if comp_a and comp_b:
			# Simulate some computation
			var _result = comp_a.serialize()
			var _result2 = comp_b.serialize()
	
			# Simulate conditional logic
			if process_count % 10 == 0:
				# Occasionally add a component
				if not entity.has_component(C_TestC):
					entity.add_component(C_TestC.new())
	
	
func reset_count():
	process_count = 0
