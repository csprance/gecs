## Test system that verifies column data
class_name ArchetypeColumnDataTestSystem
extends System

var values_seen = []


func query() -> QueryBuilder:
	return ECS.world.query.with_all([C_TestA]).iterate([C_TestA])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var test_a_components = components[0]
	for comp in test_a_components:
		if comp:
			values_seen.append(comp.value)
