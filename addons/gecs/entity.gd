## Entity[br]
## Represents an entity within the [_ECS] framework. [br]
## An entity is a container that can hold multiple [Component]s.
##
## Entities serves as the fundamental building block for game objects, allowing for flexible and modular design.[br]
##[br]
## Entities can have [Component]s added or removed dynamically, enabling the behavior and properties of game objects to change at runtime.[br]
##[br]
## Example:
##[codeblock]	
##     var entity = Entity.new()
##     var transform = Transform.new()
##     entity.add_component(transform)
##     entity.component_added.connect(_on_component_added)
##
##     func _on_component_added(entity: Entity, component_key: String) -> void:
##         print("Component added:", component_key)
##[/codeblock]	
@icon('res://addons/gecs/assets/entity.svg')
class_name Entity
extends Node2D

## Emitted when a [Component] is added to the entity.
signal component_added(entity: Entity, component: Variant)
## Emitted when a [Component] is removed from the entity.
signal component_removed(entity: Entity, component: Variant)

## [Component]s to be attached to the entity set in the editor. These will be loaded for you and added to the [Entity]
@export var component_resources: Array[Component] = []
## [Component]s attached to the [Entity]
var components: Dictionary = {}


func _ready() -> void:
	Loggie.msg('_ready Entity Initializing Components: ', self).domain('ecs').debug()
	# Initialize components from the exported array
	for res in component_resources:
		add_component(res.duplicate(true))
	on_ready()

## Adds a single component to the entity.[br]
## [param component] - The subclass of [Component] to add[br]
## [b]Example[/b]:
## [codeblock]entity.add_component(HealthComponent)[/codeblock]
func add_component(component: Variant) -> void:
	components[component.get_script().resource_path] = component
	component_added.emit(self, component)
	Loggie.msg('Added Component: ', component.resource_path).domain('ecs').debug()


## Adds multiple components to the entity.[br]
## [param _components] An [Array] of [Component]s to add.[br]
## [b]Example:[/b]
##     [codeblock]entity.add_components([TransformComponent, VelocityComponent])[/codeblock]
func add_components(_components: Array):
	for component in _components:
		add_component(component)


## Removes a single component from the entity.[br]
## [param component] The [Component] subclass to remove.[br]
## [b]Example:[/b]
##     [codeblock]entity.remove_component(HealthComponent)[/codeblock]
func remove_component(component: Variant) -> void:
	var component_key = component.resource_path
	if components.erase(component.resource_path):
		Loggie.msg('Removed Component: ', component.resource_path).domain('ecs').debug()
		component_removed.emit(self, component)

## Removes multiple components from the entity.[br]
## [param _components] An array of components to remove.[br]
##
## [b]Example:[/b]
##     [codeblock]entity.remove_components([transform_component, velocity_component])[/codeblock]
func remove_components(_components: Array):
	for _component in _components:
		remove_component(_component)

## Retrieves a specific [Component] from the entity.[br]
## [param component] The [Component] class to retrieve.[br]
## [param return] - The requested [Component] if it exists, otherwise `null`.[br]
## [b]Example:[/b]
##     [codeblock]var transform = entity.get_component(Transform)[/codeblock]
func get_component(component: Variant) -> Component:
	return components.get(component.resource_path, null)


# Lifecycle methods

## Called after the entity is fully initialized and ready.[br]
## Override this method to perform additional setup after all components have been added.
func on_ready() -> void:
	pass

## Called every time the entity is updated in a system.[br]
## Override this method to perform per-frame updates on the entity.[br]
## [param delta] The time elapsed since the last frame.
func on_update(delta: float) -> void:
	pass

## Called right before the entity is freed from memory.[br]
## Override this method to perform any necessary cleanup before the entity is destroyed.
func on_destroy() -> void:
	pass
