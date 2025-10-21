## Test system that doesn't call iterate() (should error)
class_name ArchetypeNoIterateSystem
extends System

var processed = 0


func query() -> QueryBuilder:
	return ECS.world.query.with_all([C_TestA]) # Missing .iterate()!


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	processed += 1
