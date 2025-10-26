class_name TestSystemWithGroup
extends System

var entities_found := []


func query():
	return q.with_group(["TestGroup"])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	entities_found = entities.duplicate()
