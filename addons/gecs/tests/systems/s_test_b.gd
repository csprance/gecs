class_name TestBSystem
extends System


func deps():
	return {
		Runs.After: [TestASystem], # Runs after SystemA
		Runs.Before: [TestCSystem], # This system rubs before SystemC
	}


func query():
	return q.with_all([C_TestB])


func process(entity: Entity, delta: float):
	var a = entity.get_component(C_TestB)
	a.value += 1
	print("TestBSystem: ", a.value)
