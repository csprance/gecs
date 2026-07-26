class_name GecsData
extends Resource

## Save format version. "0.3": entity ids are int generational handles
## (pre-0.3 saves stored String UUIDs) and the optional `alias` field exists.
@export var version: String = "0.3"
@export var entities: Array[GecsEntityData] = []


func _init(_entities: Array[GecsEntityData] = []):
	entities = _entities
