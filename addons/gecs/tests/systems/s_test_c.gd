class_name TestCSystem
extends System


func deps():
	return {
		Runs.After: [TestBSystem], # Runs after SystemA
		Runs.Before: [TestDSystem], # This system rubs before SystemC
	}


func query():
	return ECS.world.query.with_all([C_TestC])


func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		var a = entity.get_component(C_TestC)
		a.value += 1
		print("TestASystem: ", a.value)
