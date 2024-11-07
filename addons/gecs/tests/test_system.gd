extends GutTest

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")

class MockSystem extends System:
	var processed_entities = []
	func query():
		return q.with_all([C_TestA])

	func process(entity, delta):
		processed_entities.append(entity)

func test_system_processes_entities_with_required_components():
	var system = MockSystem.new()
	var entity_with_component = Entity.new()
	var comp = C_TestA.new()
	entity_with_component.add_component(comp)
	var entity_without_component = Entity.new()
	var entities = [entity_with_component, entity_without_component]
	system.process_entities(entities, 0.1)
	assert_eq(system.processed_entities.size(), 2, "System should process entities fed into it.")
	assert_eq(system.processed_entities, entities, "System should process the correct entity.")
