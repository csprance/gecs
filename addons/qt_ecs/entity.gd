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

func add_component(component: Component) -> void:
	components[component.key] = component
	component_added.emit(self, component.key)

func remove_component(component_key: String) -> void:
	if components.erase(component_key):
		component_removed.emit(self, component_key)

func get_component(component: Variant) -> Component:
	return components.get(component.new().key, null)

func has_component(component_key: String) -> bool:
	return components.has(component_key)

# Lifecycle methods
func on_ready() -> void:
	pass

func on_update(delta: float) -> void:
	pass

func on_destroy() -> void:
	pass
