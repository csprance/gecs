## Simple test system for performance benchmarking
class_name PerformanceTestSystem
extends System

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")

var process_count: int = 0


func query():
	return q.with_all([C_TestA])


func process(entity: Entity, delta: float) -> void:
	process_count += 1
	# Simulate some light processing
	var component = entity.get_component(C_TestA)
	if component:
		# Access component data (simulates typical system work)
		var _data = component.serialize()


func reset_count():
	process_count = 0
