extends System

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")

func query():
	return q.with_all([C_TestA])

func process(entity: Entity, delta: float):
	var a = entity.get_component(C_TestA)
	a.value += 1
	print("TestASystem: ", a.value)
