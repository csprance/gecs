## Entity
##
## Represents an entity within the ECS framework. An entity is a container that can hold multiple components.
## It serves as the fundamental building block for game objects, allowing for flexible and modular design.
##
## Entities can have components added or removed dynamically, enabling the behavior and properties of game objects to change at runtime.
##
## Signals:
##     component_added(entity: Entity, component_key: String): Emitted when a component is added to the entity.
##     component_removed(entity: Entity, component_key: String): Emitted when a component is removed from the entity.
##
## Example:
##     var entity = Entity.new()
##     var transform = Transform.new()
##     entity.add_component(transform)
##     entity.component_added.connect(_on_component_added)
##
##     func _on_component_added(entity: Entity, component_key: String) -> void:
##         print("Component added:", component_key)
@icon('res://addons/qt_ecs/assets/entity.svg')
class_name Entity
extends Node2D

signal component_added(entity: Entity, component_key: String)
signal component_removed(entity: Entity, component_key: String)

@export var component_resources: Array[Component] = []

var components: Dictionary = {}


func _ready() -> void:
	Loggie.debug('_ready Entity Initializing Components: ', self)
	# Initialize components from the exported array
	add_components(component_resources)
	on_ready()

## Adds a single component to the entity.
##
## @param component The component to add. It should be a subclass of `Component`.
##
## Example:
##     entity.add_component(HealthComponent)
func add_component(component: Variant) -> void:
	 # Make sure to duplicate the resource or we'll share the same component
	components[component.get_script().resource_path] = component.duplicate()
	component_added.emit(self, component.get_script().resource_path)
	Loggie.debug('Added Component: ', component.resource_path)


## Adds multiple components to the entity.
##
## @param _components An array of components to add.
##
## Example:
##     entity.add_components([TransformComponent, VelocityComponent])
func add_components(_components: Array):
	for component in _components:
		add_component(component)


## Removes a single component from the entity.
##
## @param component The component to remove. It should be a subclass of `Component`.
##
## Example:
##     entity.remove_component(health_component)
func remove_component(component: Variant) -> void:
	var component_key = component.resource_path
	if components.erase(component.resource_path):
		Loggie.debug('Removed Component: ', component.resource_path)
		component_removed.emit(self, component.resource_path)

## Removes multiple components from the entity.
##
## @param _components An array of components to remove.
##
## Example:
##     entity.remove_components([transform_component, velocity_component])
func remove_components(_components: Array):
	for _component in _components:
		remove_component(_component)

## Retrieves a specific component from the entity.
##
## @param component The component class to retrieve.
## @return Component The requested component if it exists, otherwise `null`.
##
## Example:
##     var transform = entity.get_component(Transform)
func get_component(component: Variant) -> Component:
	return components.get(component.resource_path, null)

## Checks if the entity has a specific component.
##
## @param component_key The resource path of the component to check.
## @return bool `true` if the component exists, otherwise `false`.
##
## Example:
##     if entity.has_component(Transform.resource_path):
##         print("Entity has a Transform component.")
func has_component(component_key: String) -> bool:
	return components.has(component_key)


# Lifecycle methods

## Called after the entity is fully initialized and ready.
##
## Override this method to perform additional setup after all components have been added.
func on_ready() -> void:
	pass

## Called every time the entity is updated in a system.
##
## @param delta The time elapsed since the last frame.
##
## Override this method to perform per-frame updates on the entity.
func on_update(delta: float) -> void:
	pass

## Called right before the entity is freed from memory.
##
## Override this method to perform any necessary cleanup before the entity is destroyed.
func on_destroy() -> void:
	pass
