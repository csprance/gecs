class_name GecsEntityData
extends Resource

@export var entity_name: String = ""
@export var scene_path: String = ""
@export var components: Array[Component] = []

func _init(_name: String = "", _scene_path: String = "", _components: Array[Component] = []):
	entity_name = _name
	scene_path = _scene_path
	components = _components
