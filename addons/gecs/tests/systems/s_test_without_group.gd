class_name TestSystemWithoutGroup
extends System

var entities_found := []


func query():
	return q.without_group(["TestGroup"])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	entities_found = entities.duplicate()
