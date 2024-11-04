@icon('res://addons/qt_ecs/assets/world.svg')
class_name World
extends Node

var entities: Array = []
var systems: Array  = []

# Component to Entities Index
var component_entity_index: Dictionary = {}

func _ready() -> void:
	# Add entities from the scene tree
	entities = find_children('*', 'Entity2D') as Array[Entity]
	print('_ready self.entities', entities)
	for entity in entities:
		add_entity(entity)
	systems = find_children('*', 'System') as Array[System]
	print('_ready self.systems', systems)
			
func add_entity(entity: Entity) -> void:
	# Update index
	print('add_entity', entity)
	for component_class in entity.components.keys():
		_add_entity_to_index(entity, component_class)
		# Connect to component signals
		entity.component_added.connect(_on_entity_component_removed)
		entity.component_removed.connect(_on_entity_component_removed)

func remove_entity(entity) -> void:
	print('remove entitiy', entity)
	entities.erase(entity)
	# Update index
	for component_class in entity.components.keys():
		_remove_entity_from_index(entity, component_class)
	entity.queue_free()

func add_system(system: System) -> void:
	print('add_system', system)
	systems.append(system)
	add_child(system)

func _process(delta: float) -> void:
	for system in systems:
		var entities_to_process: Array = query(system.required_components)
		print('_process Processing entities', entities_to_process)
		for entity in entities_to_process:
			print('system running', system, entity, delta)
			system.process(entity, delta)

func entity_has_required_components(entity: Entity, components) -> bool:
	for component_class in components:
		if not entity.has_component(component_class):
			return false
	return true

# Advanced Query Function
func query(all_components = [], any_components = [], exclude_components = []) -> Array:
	var result: Array = []
	var initialized := false

	# Include entities that have all components in all_components
	if all_components.size() > 0:
		var first_component_entities = component_entity_index.get(all_components[0], [])
		result = first_component_entities.duplicate()
		for i in range(1, all_components.size()):
			var component_class = all_components[i]
			var entities_with_component = component_entity_index.get(component_class, [])
			result = _intersect_entity_arrays(result, entities_with_component)
		initialized = true

	# Include entities that have any components in any_components
	if any_components.size() > 0:
		var any_result: Array = []
		for component_class in any_components:
			var entities_with_component = component_entity_index.get(component_class, [])
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
	for component_class in exclude_components:
		var entities_with_component = component_entity_index.get(component_class, [])
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
func _add_entity_to_index(entity, component_class) -> void:
	if not component_entity_index.has(component_class):
		component_entity_index[component_class] = []
	var entity_list = component_entity_index[component_class]
	if not entity_list.has(entity):
		entity_list.append(entity)

func _remove_entity_from_index(entity, component_class) -> void:
	if component_entity_index.has(component_class):
		var entity_list = component_entity_index[component_class]
		entity_list.erase(entity)
		if entity_list.empty():
			component_entity_index.erase(component_class)

# Signal Callbacks
func _on_entity_component_added(component_class, entity) -> void:
	_add_entity_to_index(entity, component_class)

func _on_entity_component_removed(component_class, entity) -> void:
	_remove_entity_from_index(entity, component_class)
