class_name GecsSettings
extends Node

const project_settings = {
    'entity_base_type': {
		"path": "gecs/entity_base_type",
		"default_value" : 'Node2D',
		"type" : TYPE_STRING,
		"hint" : PROPERTY_HINT_ENUM,
		"hint_string" : "Node2D,Node3D",
		"doc" : "What should the Entity base type be.",
	}
}