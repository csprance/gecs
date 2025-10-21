## Test system that tracks multiple archetype calls
class_name ArchetypeMultipleArchetypesTestSystem
extends System

var archetype_call_count = 0
var total_entities_processed = 0


func query() -> QueryBuilder:
	return ECS.world.query.with_all([C_TestA, C_TestB]).iterate([C_TestA, C_TestB])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	archetype_call_count += 1
	total_entities_processed += entities.size()
