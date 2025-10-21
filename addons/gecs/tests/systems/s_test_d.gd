class_name TestDSystem
extends System


func deps():
	return {
		Runs.After: [ECS.wildcard], # Runs after all other systems
		# If we exclude Rubs.Before it will be ignored
		# Runs.Before: [], # We could also set it to an empty array
	}


func query():
	return ECS.world.query.with_all([C_TestC])


func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		var a = entity.get_component(C_TestC)
		a.value += 1
		print("TestASystem: ", a.value)
