## Basic archetype test system
class_name ArchetypeTestSystem
extends System

var archetype_call_count = 0
var entities_processed = 0


func query() -> QueryBuilder:
	return ECS.world.query.with_all([C_TestA]).iterate([C_TestA])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	archetype_call_count += 1
	entities_processed += entities.size()
