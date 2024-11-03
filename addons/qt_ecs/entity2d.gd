@icon('res://addons/qt_ecs/assets/entity.svg')
class_name Entity2D
extends Node2D

signal component_added(component_class)
signal component_removed(component_class)

var id: int = 0

@export var component_resources: Array[Component] = []

var components: Dictionary = {}

func _ready() -> void:
	# Initialize components from the exported array
	for component in component_resources:
		add_component(component)

	on_start()

func add_component(component: Variant) -> void:
	var component_class: String = component.get_class()
	components[component_class] = component
	emit_signal("component_added", component_class)

func remove_component(component_class: String) -> void:
	if components.erase(component_class):
		emit_signal("component_removed", component_class)

func get_component(component_type: Variant) -> Component:
	return components.get(component_type.get_class(), null)

func has_component(component_class: String) -> bool:
	return components.has(component_class)

# Lifecycle methods
func on_start() -> void:
	pass

func on_update(delta: float) -> void:
	pass

func on_destroy() -> void:
	pass
