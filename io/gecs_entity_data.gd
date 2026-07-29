class_name GecsEntityData
extends Resource

@export var entity_name: String = ""
@export var scene_path: String = ""
@export var components: Array[Component] = []
@export var relationships: Array[GecsRelationshipData] = []
@export var auto_included: bool = false
## Entity identity handle. v9+ saves store the int [member Entity.id] verbatim.
## Legacy (pre-v9) saves stored a String UUID here — @export_storage keeps the
## property untyped so old files load their String verbatim and GECSIO can apply
## the legacy shim (fresh handle + load-time old-id mapping) instead of silently
## coercing the UUID to 0.
@export_storage var id = 0
## Optional semantic alias ([member Entity.alias]); "" when unset.
## Missing from legacy saves — defaults to "" for backward compatibility.
@export var alias: String = ""


func _init(
	_name: String = "",
	_scene_path: String = "",
	_components: Array[Component] = [],
	_relationships: Array[GecsRelationshipData] = [],
	_auto_included: bool = false,
	_id: int = 0,
	_alias: String = ""
):
	entity_name = _name
	scene_path = _scene_path
	components = _components
	relationships = _relationships
	auto_included = _auto_included
	id = _id
	alias = _alias
