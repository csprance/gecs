## World[br]
## Represents the game world in the [_ECS] framework, managing all [Entity]s and [System]s.[br]
##
## The World class handles the addition and removal of [Entity]s and [System]s, and orchestrates the processing of [Entity]s through [System]s each frame.[br]
## The World class also maintains an index mapping of components to entities for efficient querying.[br]
##[br]
## [b]Example:[/b]
##[codeblock]
##     func _process(delta: float) -> void:
##         for system in systems:
##             var entities_to_process = ECS.buildQuery().all(system.required_components).execute()
##             system.process_entities(entities_to_process, delta)
##[/codeblock]
@icon('res://addons/qt_ecs/assets/world.svg')
class_name World
extends Node

## Emitted when an entity is added
signal entity_added(entity: Entity)
## Emitted when an entity is removed
signal entity_removed(entity: Entity)
## Emitted when a system is added
signal system_added(system: System)
## Emitted when a system is removed
signal system_removed(system: System)

## Where are all the [Entity] nodes placed in the scene tree?
@export var entity_nodes_root: NodePath
## Where are all the [System] nodes placed in the scene tree?
@export var system_nodes_root: NodePath

## All the [Entity]s in the world.
var entities: Array[Entity] = []
## All the [System]s in the world.
var systems: Array[System]  = []
## [Component] to [Entity] Index - This stores entities by component for efficient querying.
var component_entity_index: Dictionary = {}

## Called when the World node is ready.[br]
## Adds [Entity]s and [System]s from the scene tree to the [World].
func _ready() -> void:
	# Add entities from the scene tree
	var _entities = find_children('*', "Entity") as Array[Entity]
	add_entities(_entities)
	Loggie.msg('_ready Added Entities from Scene Tree: ', _entities).domain('ecs').debug()

	# Add systems from scene tree
	var _systems  = find_children('*', "System") as Array[System]
	add_systems(_systems)
	Loggie.msg('_ready Added Systems from Scene Tree: ', _systems).domain('ecs').debug()

## Called every frame by the [method _ECS.process] to process [System]s.[br]
## [param delta] The time elapsed since the last frame.
func process(delta: float) -> void:
	for system in systems:
		system._handle(
			delta
		)

## Adds a single [Entity] to the world.[br]
## [param entity] The [Entity] to add.[br]
## [b]Example:[/b]
##    [codeblock] world.add_entity(player_entity)[/codeblock]
func add_entity(entity: Entity) -> void:
	if not entity.is_inside_tree():
		add_child(entity)
	# Update index
	Loggie.msg('add_entity Adding Entity to World: ', entity).domain('ecs').debug()
	entities.append(entity)
	entity_added.emit(entity)
	for component_key in entity.components.keys():
		_add_entity_to_index(entity, component_key)

	# Connect to entity signals for components so we can track global component state
	entity.component_added.connect(_on_entity_component_added)
	entity.component_removed.connect(_on_entity_component_removed)

## Adds multiple entities to the world.
##
## @param _entities An array of entities to add.
##
## [b]Example:[/b]
##      [codeblock]world.add_entities([player_entity, enemy_entity])[/codeblock]
func add_entities(_entities: Array):
	for _entity in _entities:
		add_entity(_entity)

## Adds a single system to the world.
##
## @param system The system to add.
##
## [b]Example:[/b]
##      [codeblock]world.add_system(movement_system)[/codeblock]
func add_system(system: System) -> void:
	Loggie.msg('add_system Adding System: ', system).domain('ecs').debug()
	systems.append(system)
	system_added.emit(system)

## Adds multiple systems to the world.
##
## @param _systems An array of systems to add.
##
## [b]Example:[/b]
##      [codeblock]world.add_systems([movement_system, render_system])[/codeblock]
func add_systems(_systems: Array):
	for _system in _systems:
		add_system(_system)

## Removes an [Entity] from the world.[br]
## [param entity] The [Entity] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_entity(player_entity)[/codeblock]
func remove_entity(entity) -> void:
	Loggie.msg('remove_entity Removing Entity: ', entity).domain('ecs').debug()
	entities.erase(entity)
	# Update index
	for component_key in entity.components.keys():
		_remove_entity_from_index(entity, component_key)

	entity = entity as Entity
	entity_removed.emit(entity)
	entity.component_added.disconnect(_on_entity_component_added)
	entity.component_removed.disconnect(_on_entity_component_removed)
	entity.on_destroy()
	entity.queue_free()

## Removes a [System] from the world.[br]
## [param system] The [System] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_system(movement_system)[/codeblock]
func remove_system(system) -> void:
	Loggie.msg('remove_system Removing System: ', system).domain('ecs').debug()
	systems.erase(system)
	system_removed.emit(system)
	# Update index
	system.queue_free()

## Maps a [Component] to its [member Resource.resource_path].[br]
## [param x] The [Component] to map.[br]
## [param returns] The resource path of the component.
func map_resource_path(x) -> String:
	return x.resource_path


## Executes a query to retrieve entities based on component criteria.[br]
## [param all_components] - [Component]s that [Entity]s must have all of.[br]
## [param any_components] - [Component]s that [Entity]s must have at least one of.[br]
## [param exclude_components] - [Component]s that [Entity]s must not have.[br]
## [param returns] An [Array] of [Entity]s that match the query.
func query(all_components = [], any_components = [], exclude_components = []) -> Array:
	# if they're all empty return an empty array
	if all_components.size() == 0 and any_components.size() == 0 and exclude_components.size() == 0:
		return []

	var result: Array              =  []
	var initialized                := false
	var _all_components: Array     =  all_components.map(map_resource_path)
	var _any_components: Array     =  any_components.map(map_resource_path)
	var _exclude_components: Array =  exclude_components.map(map_resource_path)

	# Include entities that have all components in _all_components
	if _all_components.size() > 0:
		var first_component_entities = component_entity_index.get(_all_components[0], [])
		result = first_component_entities.duplicate()
		for i in range(1, _all_components.size()):
			var component_key: String   = _all_components[i]
			var entities_with_component = component_entity_index.get(component_key, [])
			result = _intersect_entity_arrays(result, entities_with_component)
		initialized = true

	# Include entities that have any components in any_components
	if _any_components.size() > 0:
		var any_result: Array = []
		for component_key in _any_components:
			var entities_with_component = component_entity_index.get(component_key, [])
			any_result = _union_entity_arrays(any_result, entities_with_component)
		if initialized:
			result = _intersect_entity_arrays(result, any_result)
		else:
			result = any_result.duplicate()
			initialized = true

	if not initialized:
		# If no components specified, return all entities
		result = entities.duplicate()

	# Exclude entities that have components in exclude_components
	for component_key in _exclude_components:
		var entities_with_component = component_entity_index.get(component_key, [])
		result = _difference_entity_arrays(result, entities_with_component)

	#Loggie.debug('Query Result: ', result)
	return result


# Helper functions for array operations

## Intersects two arrays of entities.[br]
## @param array1 The first array.[br]
## @param array2 The second array.[br]
## @return Array The intersection of the two arrays.
func _intersect_entity_arrays(array1, array2) -> Array:
	var result: Array = []
	for entity in array1:
		if array2.has(entity):
			result.append(entity)
	return result

## Unions two arrays of entities.[br]
## @param array1 The first array.[br]
## @param array2 The second array.[br]
## @return Array The union of the two arrays.
func _union_entity_arrays(array1, array2) -> Array:
	var result = array1.duplicate()
	for entity in array2:
		if not result.has(entity):
			result.append(entity)
	return result

## Differences two arrays of entities.[br]
## @param array1 The first array.[br]
## @param array2 The second array.[br]
## @return Array The difference of the two arrays (entities in array1 not in array2).
func _difference_entity_arrays(array1, array2) -> Array:
	var result: Array = []
	for entity in array1:
		if not array2.has(entity):
			result.append(entity)
	return result


# Index Management Functions

## Adds an entity to the component index.[br]
## @param entity The entity to index.[br]
## @param component_key The component's resource path.
func _add_entity_to_index(entity: Entity, component_key: String) -> void:
	if not component_entity_index.has(component_key):
		component_entity_index[component_key] = []
	var entity_list = component_entity_index[component_key]
	if not entity_list.has(entity):
		entity_list.append(entity)

## Removes an entity from the component index.[br]
## @param entity The entity to remove.[br]
## @param component_key The component's resource path.
func _remove_entity_from_index(entity, component_key: String) -> void:
	if component_entity_index.has(component_key):
		var entity_list: Array = component_entity_index[component_key]
		entity_list.erase(entity)
		if entity_list.size() == 0:
			component_entity_index.erase(component_key)


# Signal Callbacks

## [signal Entity.component_added] Callback when a component is added to an entity.[br]
## @param entity The entity that had a component added.[br]
## @param component_key The resource path of the added component.
func _on_entity_component_added(entity, component_key: String) -> void:
	_add_entity_to_index(entity, component_key)

## [signal Entity.component_removed] Callback when a component is removed from an entity.[br]
## @param entity The entity that had a component removed.[br]
## @param component_key The resource path of the removed component.
func _on_entity_component_removed(entity, component_key: String) -> void:
	_remove_entity_from_index(entity, component_key)
