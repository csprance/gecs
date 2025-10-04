class_name TestASystem
extends System


func deps():
	return {
		Runs.After: [], # Doesn't run after any other system
		Runs.Before: [ECS.wildcard], # This system runs before all other systems
	}


func query():
	return q.with_all([C_TestA])


func process(entity: Entity, delta: float):
	var a = entity.get_component(C_TestA) as C_TestA
	a.value += 1
	a.property_changed.emit(a, 'value', null, null)
	print("TestASystem: ", entity.name, a.value)