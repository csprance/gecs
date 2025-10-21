## Test system that modifies components
class_name ArchetypeModifyTestSystem
extends System


func query() -> QueryBuilder:
	return ECS.world.query.with_all([C_TestA]).iterate([C_TestA])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var test_a_components = components[0]
	for comp in test_a_components:
		if comp:
			comp.value += 1
