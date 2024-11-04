@icon('res://addons/qt_ecs/assets/entity.svg')
class_name Entity
extends Node2D

signal component_added(entity: Entity, component_key: String)
signal component_removed(entity: Entity, component_key: String)


@export var component_resources: Array[Component] = []


var components: Dictionary = {}


func _ready() -> void:
	# Initialize components from the exported array
	for component in component_resources:
		add_component(component)
		
	on_ready()

func add_component(component: Variant) -> void:
	components[component.key] = component
	component_added.emit(self, component.key)

func remove_component(component: Variant) -> void:
	var component_key = component.resource_path
	if components.erase(component.resource_path):
		component_removed.emit(self, component.resource_path)

func get_component(component: Variant) -> Component:
	return components.get(component.resource_path, null)

func has_component(component_key: String) -> bool:
	return components.has(component_key)

# Lifecycle methods
func on_ready() -> void:
	pass

func on_update(delta: float) -> void:
	pass

func on_destroy() -> void:
	pass
