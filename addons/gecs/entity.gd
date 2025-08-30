## Entity[br]
## Represents an entity within the [_ECS] framework. [br]
## An entity is a container that can hold multiple [Component]s.
##
## Entities serves as the fundamental building block for game objects, allowing for flexible and modular design.[br]
##[br]
## Entities can have [Component]s added or removed dynamically, enabling the behavior and properties of game objects to change at runtime.[br]
## Entities can have [Relationship]s added or removed dynamically, allowing for a deep heirachical query system.[br]
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
@icon("res://addons/gecs/assets/entity.svg")
@tool
class_name Entity
extends Node

## Emitted when a [Component] is added to the entity.
signal component_added(entity: Entity, component: Resource)
## Emitted when a [Component] is removed from the entity.
signal component_removed(entity: Entity, component: Resource)
## Emitted when a [Component] property is changed.
signal component_property_changed(
	entity: Entity,
	component: Resource,
	property_name: String,
	old_value: Variant,
	new_value: Variant
)
## Emit when a [Relationship] is added to the [Entity]
signal relationship_added(entity: Entity, relationship: Relationship)
## Emit when a [Relationship] is removed from the [Entity]
signal relationship_removed(entity: Entity, relationship: Relationship)

## Is this entity active? (Will show up in queries)
@export var enabled: bool = true
## [Component]s to be attached to the entity set in the editor. These will be loaded for you and added to the [Entity]
@export var component_resources: Array[Component] = []

## [Component]s attached to the [Entity] in the form of Dict[resource_path:String, Component]
var components: Dictionary = {}
## Relationships attached to the entity
var relationships: Array[Relationship] = []
## Cache for component resource paths to avoid repeated .get_script().resource_path calls
var _component_path_cache: Dictionary = {}

## Logger for entities to only log to a specific domain
var _entityLogger = GECSLogger.new().domain("Entity")
## We can store ephemeral state on the entity
var _state = {}


## Called when the entity is added to the scene tree.
func _ready() -> void:
	if Engine.is_editor_hint():
		# This is the editor, so we don't want to initialize components
		return
	_initialize()


func _initialize():
	_entityLogger.trace("Entity Initializing Components: ", self.name)

	# Add components defined in code
	component_resources.append_array(define_components())

	# remove any component_resources that are already defined in components
	# This is useful for when you instantiate an entity from a scene and want to overide components
	for component in component_resources:
		if has_component(component.get_script()):
			component_resources.erase(component)

	# Initialize components from the exported array
	for res in component_resources:
		add_component(res.duplicate(true))

	# Call the lifecycle method on_ready
	on_ready()


## ##################################
## Components
## ##################################


## Adds a single component to the entity.[br]
## [param component] - The subclass of [Component] to add[br]
## [b]Example[/b]:
## [codeblock]entity.add_component(HealthComponent)[/codeblock]
func add_component(component: Resource) -> void:
	# Cache the resource path to avoid repeated calls
	var resource_path = component.get_script().resource_path
	
	# If a component of this type already exists, remove it first
	if components.has(resource_path):
		var existing_component = components[resource_path]
		remove_component(existing_component)
	
	_component_path_cache[component] = resource_path
	components[resource_path] = component
	if not component.property_changed.is_connected(_on_component_property_changed):
		component.property_changed.connect(_on_component_property_changed)
	## Adding components happens through a signal
	component_added.emit(self, component)
	_entityLogger.trace("Added Component: ", resource_path)


func _on_component_property_changed(
	component: Resource, property_name: String, old_value: Variant, new_value: Variant
) -> void:
	# Pass this signal on to the world
	component_property_changed.emit(self, component, property_name, old_value, new_value)


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
func remove_component(component: Resource) -> void:
	# Use cached path if available, otherwise get it from the component class
	var resource_path: String
	if _component_path_cache.has(component):
		resource_path = _component_path_cache[component]
		_component_path_cache.erase(component)
	else:
		# Component parameter should be a class/script, consistent with has_component
		resource_path = component.resource_path

	if components.erase(resource_path):
		component_removed.emit(self, component)
		# Removing components happens immediately
		ECS.world._remove_entity_from_index(self, resource_path)
		_entityLogger.trace("Removed Component: ", resource_path)


func deferred_remove_component(component: Resource) -> void:
	call_deferred_thread_group("remove_component", component)


## Removes multiple components from the entity.[br]
## [param _components] An array of components to remove.[br]
##
## [b]Example:[/b]
##     [codeblock]entity.remove_components([transform_component, velocity_component])[/codeblock]
func remove_components(_components: Array):
	for _component in _components:
		remove_component(_component)


##  Removes all components from the entity.[br]
## [b]Example:[/b]
##     [codeblock]entity.remove_all_components()[/codeblock]
func remove_all_components() -> void:
	for component in components.values():
		remove_component(component)


## Retrieves a specific [Component] from the entity.[br]
## [param component] The [Component] class to retrieve.[br]
## [param return] - The requested [Component] if it exists, otherwise `null`.[br]
## [b]Example:[/b]
##     [codeblock]var transform = entity.get_component(Transform)[/codeblock]
func get_component(component: Resource) -> Component:
	return components.get(component.resource_path, null)


## Check to see if an entity has a  specific component on it.[br]
## This is useful when you're checking to see if it has a component and not going to use the component itself.[br]
## If you plan on getting and using the component, use [method get_component] instead.
func has_component(component: Resource) -> bool:
	return components.has(component.resource_path)


## ##################################
## Relationships
## ##################################


## Adds a relationship to this entity.[br]
## [param relationship] The [Relationship] to add.
func add_relationship(relationship: Relationship) -> void:
	relationship.source = self
	relationships.append(relationship)
	relationship_added.emit(self, relationship)


func add_relationships(_relationships: Array):
	for relationship in _relationships:
		add_relationship(relationship)


## Removes a relationship from the entity.[br]
## [param relationship] The [Relationship] to remove.
func remove_relationship(relationship: Relationship) -> void:
	var to_remove = []
	for rel in relationships:
		if rel.matches(relationship):
			to_remove.append(rel)
	for rel in to_remove:
		relationships.erase(rel)
		relationship_removed.emit(self, rel)


func remove_relationships(_relationships: Array):
	for relationship in _relationships:
		remove_relationship(relationship)


## Retrieves a specific [Relationship] from the entity.
## [param relationship] The [Relationship] to retrieve.
## [param return] - The FIRST matching [Relationship] if it exists, otherwise `null` or `[]` if single = false
func get_relationship(relationship: Relationship, single = true, weak = false):
	var results = []
	var to_remove = []
	for rel in relationships:
		# Check if the relationship is valid
		if not rel.valid():
			to_remove.append(rel)
			continue
		if rel.matches(relationship, weak):
			if single:
				return rel
			results.append(rel)
	# Remove invalid relationships
	for rel in to_remove:
		relationships.erase(rel)
		relationship_removed.emit(self, rel)
	var retval = null if results.is_empty() else results
	if not single and retval == null:
		return []

	return retval


## Retrieves [Relationship]s from the entity.
## [param relationship] The [Relationship]s to retrieve.
## [param return] - All matching [Relationship]s if it exists, otherwise `null`.
func get_relationships(relationship: Relationship, weak = false) -> Array:
	return get_relationship(relationship, false, weak)


## Checks if the entity has a specific relationship.[br]
## [param relationship] The [Relationship] to check for.
func has_relationship(relationship: Relationship, weak = false) -> bool:
	return get_relationship(relationship, true, weak) != null


## ##################################
# Lifecycle methods
## ##################################


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


## Called when the entity is disabled.[br]
func on_disable() -> void:
	pass


## Called when the entity is enabled.[br]
func on_enable() -> void:
	pass


## Define the default components in code to use (Instead of in the editor)[br]
## This should return a list of components to add by default when the entity is created
func define_components() -> Array:
	return []
