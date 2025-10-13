class_name GecsEntityData
extends Resource

@export var entity_name: String = ""
@export var scene_path: String = ""
@export var components: Array[Component] = []
@export var relationships: Array[GecsRelationshipData] = []
@export var auto_included: bool = false
@export var id: String = ""

func _init(_name: String = "", _scene_path: String = "", _components: Array[Component] = [], _relationships: Array[GecsRelationshipData] = [], _auto_included: bool = false, _id: String = ""):
	entity_name = _name
	scene_path = _scene_path
	components = _components
	relationships = _relationships
	auto_included = _auto_included
	id = _id
