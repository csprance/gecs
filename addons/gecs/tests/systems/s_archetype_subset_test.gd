## Test system that queries for subset of entity components
class_name ArchetypeSubsetTestSystem
extends System

var entities_processed = 0


func query() -> QueryBuilder:
	# Query for A and B, even though entity has A, B, C
	return ECS.world.query.with_all([C_TestA, C_TestB]).iterate([C_TestA, C_TestB])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	entities_processed += entities.size()
