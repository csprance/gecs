class_name TestSystemWithRelationship
extends System

var entities_found := []


func query():
	return q.with_relationship([Relationship.new(C_TestA.new(), null)])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	entities_found = entities.duplicate()
