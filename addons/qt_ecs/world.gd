@icon('res://addons/qt_ecs/assets/world.svg')
class_name World
extends Node

var entities: Array = []
var systems: Array  = []
# Component to Entities Index
var component_entity_index: Dictionary = {}


func _ready() -> void:
	# Add entities from the scene tree
	var _entities = find_children('*', 'Entity') as Array[Entity]
	var _systems = find_children('*', 'System') as Array[System]
	print('_ready Adding Entities from Scene Tree: ', entities)
	print('_ready Adding Systems from Scene Tree: ', systems)
	for entity in _entities:
		add_entity(entity)
	for system in _systems:
		add_system(system)


func add_entity(entity: Entity) -> void:
	# Update index
	print('add_entity Adding Entity to World', entity)
	entities.append(entity)
	for component_key in entity.components.keys():
		_add_entity_to_index(entity, component_key)
		# Connect to entity signals for components so we can track global component state
		entity.component_added.connect(_on_entity_component_added)
		entity.component_removed.connect(_on_entity_component_removed)

func add_system(system: System) -> void:
	print('add_system Adding System: ', system)
	systems.append(system)
	
	
func remove_entity(entity) -> void:
	print('remove entitiy', entity)
	entities.erase(entity)
	# Update index
	for component_key in entity.components.keys():
		_remove_entity_from_index(entity, component_key)
	entity.queue_free()



func _process(delta: float) -> void:
	for system in systems:
		var entities_to_process: Array = query(system.required_components)
		for entity in entities_to_process:
			system.process(entity, delta)


func map_resource_path(x) -> String:
	return x.resource_path


# Advanced Query Function
func query(all_components = [], any_components = [], exclude_components = []) -> Array:
	var result: Array                      =  []
	var initialized                        := false
	var _all_components: Array    =  all_components.map(map_resource_path)
	var _any_components: Array    =  any_components.map(map_resource_path)
	var _exclude_components: Array =  exclude_components.map(map_resource_path)

	# Include entities that have all components in _all_components
	if _all_components.size() > 0:
		var first_component_entities = component_entity_index.get(_all_components[0], [])
		result = first_component_entities.duplicate()
		for i in range(1, _all_components.size()):
			var component_key: String         = _all_components[i]
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

	return result


# Helper functions for array operations
func _intersect_entity_arrays(array1, array2) -> Array:
	var result: Array = []
	for entity in array1:
		if array2.has(entity):
			result.append(entity)
	return result


func _union_entity_arrays(array1, array2) -> Array:
	var result = array1.duplicate()
	for entity in array2:
		if not result.has(entity):
			result.append(entity)
	return result


func _difference_entity_arrays(array1, array2) -> Array:
	var result: Array = []
	for entity in array1:
		if not array2.has(entity):
			result.append(entity)
	return result


# Index Management Functions
func _add_entity_to_index(entity: Entity, component_key: String) -> void:
	if not component_entity_index.has(component_key):
		component_entity_index[component_key] = []
	var entity_list = component_entity_index[component_key]
	if not entity_list.has(entity):
		entity_list.append(entity)


func _remove_entity_from_index(entity, component_key: String) -> void:
	if component_entity_index.has(component_key):
		var entity_list = component_entity_index[component_key]
		entity_list.erase(entity)
		if entity_list.empty():
			component_entity_index.erase(component_key)


# Signal Callbacks
func _on_entity_component_added(entity, component_key: String) -> void:
	_add_entity_to_index(entity, component_key)


func _on_entity_component_removed(entity, component_key: String) -> void:
	_remove_entity_from_index(entity, component_key)
