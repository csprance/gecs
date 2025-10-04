class_name GecsData
extends Resource

@export var version: String = "0.1"
@export var entities: Array[GecsEntityData] = []

func _init(_entities: Array[GecsEntityData] = []):
	entities = _entities
