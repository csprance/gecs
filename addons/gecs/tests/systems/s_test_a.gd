extends System

const SystemB = preload("res://addons/gecs/tests/systems/s_test_b.gd")
const SystemC = preload("res://addons/gecs/tests/systems/s_test_c.gd")
const SystemD = preload("res://addons/gecs/tests/systems/s_test_d.gd")
const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")


func deps():
	return {
		Runs.After: [],  # Doesn't run after any other system
		Runs.Before: [ECS.wildcard],  # This system runs before all other systems
	}


func query():
	return q.with_all([C_TestA])


func process(entity: Entity, delta: float):
	var a = entity.get_component(C_TestA) as C_TestA
	a.value += 1
	a.property_changed.emit(a, 'value', null, null)
	print("TestASystem: ", entity.name, a.value)
