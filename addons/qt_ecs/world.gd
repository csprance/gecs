## World
##
## Represents the game world in the ECS framework, managing all entities and systems.
## It handles the addition and removal of entities and systems, and orchestrates the processing of entities through systems each frame.
##
## The World class also maintains an index mapping of components to entities for efficient querying.
##
## Example:
##     func _process(delta: float) -> void:
##         for system in systems:
##             var entities_to_process = ECS.buildQuery().all(system.required_components).execute()
##             system.process_entities(entities_to_process, delta)
@icon('res://addons/qt_ecs/assets/world.svg')
class_name World
extends Node

var entities: Array[Entity] = []
var systems: Array[System]  = []
# Component to Entities Index
var component_entity_index: Dictionary = {}

## Called when the World node is ready.
##
## Adds entities and systems from the scene tree to the world.
func _ready() -> void:
	# Add entities from the scene tree
	var _entities = find_children('*', 'Entity') as Array[Entity]
	add_entities(_entities)
	Loggie.debug('_ready Added Entities from Scene Tree: ', entities)

	# Add systems from scene tree
	var _systems  = find_children('*', 'System') as Array[System]
	add_systems(_systems)
	Loggie.debug('_ready Added Systems from Scene Tree: ', systems)

## Called every frame to process systems.
##
## @param delta The time elapsed since the last frame.
func _process(delta: float) -> void:
	for system in systems:
		var entities_to_process: Array = ECS.buildQuery().all(system.required_components).execute()
		system.process_entities(entities_to_process, delta)

## Adds a single entity to the world.
##
## @param entity The entity to add.
##
## Example:
##     world.add_entity(player_entity)
func add_entity(entity: Entity) -> void:
	if not entity.is_inside_tree():
		add_child(entity)
	# Update index
	Loggie.debug('add_entity Adding Entity to World: ', entity)
	entities.append(entity)
	for component_key in entity.components.keys():
		_add_entity_to_index(entity, component_key)

	# Connect to entity signals for components so we can track global component state
	entity.component_added.connect(_on_entity_component_added)
	entity.component_removed.connect(_on_entity_component_removed)

## Adds multiple entities to the world.
##
## @param _entities An array of entities to add.
##
## Example:
##     world.add_entities([player_entity, enemy_entity])
func add_entities(_entities: Array):
	for _entity in _entities:
		add_entity(_entity)

## Adds a single system to the world.
##
## @param system The system to add.
##
## Example:
##     world.add_system(movement_system)
func add_system(system: System) -> void:
	Loggie.debug('add_system Adding System: ', system)
	systems.append(system)

## Adds multiple systems to the world.
##
## @param _systems An array of systems to add.
##
## Example:
##     world.add_systems([movement_system, render_system])
func add_systems(_systems: Array):
	for _system in _systems:
		add_system(_system)

## Removes an entity from the world.
##
## @param entity The entity to remove.
##
## Example:
##     world.remove_entity(player_entity)
func remove_entity(entity) -> void:
	Loggie.debug('remove_entity Removing Entity: ', entity)
	entities.erase(entity)
	# Update index
	for component_key in entity.components.keys():
		_remove_entity_from_index(entity, component_key)

	entity = entity as Entity
	entity.component_added.disconnect(_on_entity_component_added)
	entity.component_removed.disconnect(_on_entity_component_removed)
	entity.on_destroy()
	entity.queue_free()

## Removes a system from the world.
##
## @param system The system to remove.
##
## Example:
##     world.remove_system(movement_system)
func remove_system(system) -> void:
	Loggie.debug('remove_system Removing System: ', system)
	systems.erase(system)
	# Update index
	system.queue_free()

## Maps a component to its resource path.
##
## @param x The component to map.
## @return String The resource path of the component.
func map_resource_path(x) -> String:
	return x.resource_path


## Executes a query to retrieve entities based on component criteria.
##
## @param all_components Components that entities must have all of.
## @param any_components Components that entities must have at least one of.
## @param exclude_components Components that entities must not have.
## @return Array An array of entities that match the query.
func query(all_components = [], any_components = [], exclude_components = []) -> Array:
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

## Intersects two arrays of entities.
##
## @param array1 The first array.
## @param array2 The second array.
## @return Array The intersection of the two arrays.
func _intersect_entity_arrays(array1, array2) -> Array:
	var result: Array = []
	for entity in array1:
		if array2.has(entity):
			result.append(entity)
	return result

## Unions two arrays of entities.
##
## @param array1 The first array.
## @param array2 The second array.
## @return Array The union of the two arrays.
func _union_entity_arrays(array1, array2) -> Array:
	var result = array1.duplicate()
	for entity in array2:
		if not result.has(entity):
			result.append(entity)
	return result

## Differences two arrays of entities.
##
## @param array1 The first array.
## @param array2 The second array.
## @return Array The difference of the two arrays (entities in array1 not in array2).
func _difference_entity_arrays(array1, array2) -> Array:
	var result: Array = []
	for entity in array1:
		if not array2.has(entity):
			result.append(entity)
	return result


# Index Management Functions

## Adds an entity to the component index.
##
## @param entity The entity to index.
## @param component_key The component's resource path.
func _add_entity_to_index(entity: Entity, component_key: String) -> void:
	if not component_entity_index.has(component_key):
		component_entity_index[component_key] = []
	var entity_list = component_entity_index[component_key]
	if not entity_list.has(entity):
		entity_list.append(entity)

## Removes an entity from the component index.
##
## @param entity The entity to remove.
## @param component_key The component's resource path.
func _remove_entity_from_index(entity, component_key: String) -> void:
	if component_entity_index.has(component_key):
		var entity_list: Array = component_entity_index[component_key]
		entity_list.erase(entity)
		if entity_list.size() == 0:
			component_entity_index.erase(component_key)


# Signal Callbacks

## Callback when a component is added to an entity.
##
## @param entity The entity that had a component added.
## @param component_key The resource path of the added component.
func _on_entity_component_added(entity, component_key: String) -> void:
	_add_entity_to_index(entity, component_key)

## Callback when a component is removed from an entity.
##
## @param entity The entity that had a component removed.
## @param component_key The resource path of the removed component.
func _on_entity_component_removed(entity, component_key: String) -> void:
	_remove_entity_from_index(entity, component_key)
