class_name TestBSystem
extends System


func deps():
	return {
		Runs.After: [TestASystem], # Runs after SystemA
		Runs.Before: [TestCSystem], # This system rubs before SystemC
	}


func query():
	return ECS.world.query.with_all([C_TestB])


func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		var a = entity.get_component(C_TestB)
		a.value += 1
		print("TestBSystem: ", a.value)
