class_name TestSystemNonexistentGroup
extends System

var entities_found := []


func query():
	return q.with_group(["NonexistentGroup"])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	entities_found = entities.duplicate()
