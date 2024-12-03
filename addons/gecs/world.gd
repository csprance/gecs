## World[br]
## Represents the game world in the [_ECS] framework, managing all [Entity]s and [System]s.[br]
##
## The World class handles the addition and removal of [Entity]s and [System]s, and orchestrates the processing of [Entity]s through [System]s each frame.[br]
## The World class also maintains an index mapping of components to entities for efficient querying.[br]
@icon('res://addons/gecs/assets/world.svg')
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
## Emitted when a component is added to an entity
signal component_added(entity: Entity, component: Variant)
## Emitted when a component is removed from an entity
signal component_removed(entity: Entity, component: Variant)
## Emitted when a relationship is added to an entity
signal relationship_added(entity: Entity, relationship: Relationship)
## Emitted when a relationship is removed from an entity
signal relationship_removed(entity: Entity, relationship: Relationship)

## Where are all the [Entity] nodes placed in the scene tree?
@export var entity_nodes_root: NodePath
## Where are all the [System] nodes placed in the scene tree?
@export var system_nodes_root: NodePath

## All the [Entity]s in the world.
var entities: Array[Entity] = []
## All the [System]s in the world.
var systems: Array[System]  = []
## All the systems by group
var systems_by_group: Dictionary = {}
## [Component] to [Entity] Index - This stores entities by component for efficient querying.
var component_entity_index: Dictionary = {}
## The [QueryBuilder] instance for this world used to build and execute queries
var query: QueryBuilder:
	get:
		return QueryBuilder.new(self)
## Index for relationships to entities (Optional for optimization)
var relationship_entity_index: Dictionary = {}
## Index for reverse relationships (target to source entities)
var reverse_relationship_index: Dictionary = {}
## Logger for the world to only log to a specific domain
var _worldLogger =  GECSLogger.new().domain('World')

## Called when the World node is ready.[br]
func _ready() -> void:
	_initialize()

func _make_nodes_root(name: String) -> Node:
	var node = Node.new()
	node.name = name
	add_child(node)
	return node
	
## Adds [Entity]s and [System]s from the scene tree to the [World].[br]
## Called when the World node is ready.
func _initialize():
	# if no entities/systems root node is set create them and use them. This keeps things tidy for debugging
	entity_nodes_root = _make_nodes_root('Entities').get_path() if not entity_nodes_root else entity_nodes_root
	system_nodes_root = _make_nodes_root('Systems').get_path() if not system_nodes_root else system_nodes_root

	# Add entities from the scene tree
	var _entities = find_children('*', "Entity") as Array[Entity]
	add_entities(_entities)
	_worldLogger.debug('_initialize Added Entities from Scene Tree: ', _entities)

	# Add systems from scene tree
	var _systems  = find_children('*', "System") as Array[System]
	add_systems(_systems)
	_worldLogger.debug('_initialize Added Systems from Scene Tree: ', _systems)

	# Connect to entity relationship signals
	for entity in entities:
		entity.relationship_added.connect(_on_entity_relationship_added)
		entity.relationship_removed.connect(_on_entity_relationship_removed)

## Called every frame by the [method _ECS.process] to process [System]s.[br]
## [param delta] The time elapsed since the last frame.
## [param group] The string for the group we should run. If empty runs all
func process(delta: float, group: String='' ) -> void:
	# If no group specific in the group, run all systems and process was called run all system
	if group == '':
		for system in systems:
			if system.active:
				system._handle(delta)
	else:
		if systems_by_group.has(group):
			for system in systems_by_group[group]:
				if system.active:
					system._handle(delta)

## Adds a single [Entity] to the world.[br]
## [param entity] The [Entity] to add.[br]
## [param components] The optional list of [Component] to add to the entity.[br]
## [b]Example:[/b]
## [codeblock] 
## # add just an entity
## world.add_entity(player_entity)
## # add an entity with some components
## world.add_entity(other_entity, [component_a, component_b])
## [/codeblock]
func add_entity(entity: Entity, components = null) -> void:
	if not entity.is_inside_tree():
		get_node(entity_nodes_root).add_child(entity)
	# Update index
	_worldLogger.debug('add_entity Adding Entity to World: ', entity)
	entities.append(entity)
	entity_added.emit(entity)
	for component_key in entity.components.keys():
		_add_entity_to_index(entity, component_key)

	# Connect to entity signals for components so we can track global component state
	entity.component_added.connect(_on_entity_component_added)
	entity.component_removed.connect(_on_entity_component_removed)

	if components:
		entity.add_components(components)

## Adds multiple entities to the world.[br]
## @param _entities An array of entities to add.[br]
## [param components] The optional list of [Component] to add to the entity.[br]
## [b]Example:[/b]
##      [codeblock]world.add_entities([player_entity, enemy_entity], [component_a])[/codeblock]
func add_entities(_entities: Array, components = null):
	for _entity in _entities:
		add_entity(_entity, components)

## Adds a single system to the world.
##
## @param system The system to add.
##
## [b]Example:[/b]
##      [codeblock]world.add_system(movement_system)[/codeblock]
func add_system(system: System) -> void:
	if not system.is_inside_tree():
		get_node(system_nodes_root).add_child(system)
	_worldLogger.trace('add_system Adding System: ', system)
	systems.append(system)
	if not systems_by_group.has(system.group):
		systems_by_group[system.group] = []
	systems_by_group[system.group].push_back(system)
	system_added.emit(system)
	system.setup()

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
	entity = entity as Entity
	entity_removed.emit(entity)
	_worldLogger.debug('remove_entity Removing Entity: ', entity)
	entities.erase(entity) # FIXME: This doesn't always work for some reason?
	# Update index
	for component_key in entity.components.keys():
		_remove_entity_from_index(entity, component_key)
	
	entity.component_added.disconnect(_on_entity_component_added)
	entity.component_removed.disconnect(_on_entity_component_removed)
	entity.on_destroy()
	entity.queue_free()

## Removes a [System] from the world.[br]
## [param system] The [System] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_system(movement_system)[/codeblock]
func remove_system(system) -> void:
	_worldLogger.debug('remove_system Removing System: ', system)
	systems.erase(system)
	systems_by_group[system.group].erase(system)
	system_removed.emit(system)
	# Update index
	system.queue_free()

## Removes all [Entity]s and [System]s from the world.
## Optionally frees the world node by default.
func purge(should_free=true) -> void:
	_worldLogger.debug('Purging Entities', entities)
	for entity in entities.duplicate():
		remove_entity(entity)
	_worldLogger.debug('Purging Systems', systems)
	for system in systems.duplicate():
		remove_system(system)
	# remove itself
	if should_free:
		queue_free()

## Maps a [Component] to its [member Resource.resource_path].[br]
## [param x] The [Component] to map.[br]
## [param returns] The resource path of the component.
func map_resource_path(x) -> String:
	return x.resource_path


## Executes a query to retrieve entities based on component criteria.[br]
## [param all_components] - [Component]s that [Entity]s must have all of.[br]
## [param any_components] - [Component]s that [Entity]s must have at least one of.[br]
## [param exclude_components] - [Component]s that [Entity]s must not have.[br]
## [param returns] An [Array] of [Entity]s that match the query.[br]
## [br]
## Performance Optimization:[br]
## When checking for all_components, the system first identifies the component with the smallest[br]
## set of entities and starts with that set. This significantly reduces the number of comparisons needed,[br]
## as we only need to check the smallest possible set of entities against other components.
func _query(all_components = [], any_components = [], exclude_components = []) -> Array:
	# Early return if no components specified
	if all_components.is_empty() and any_components.is_empty() and exclude_components.is_empty():
		return entities
	
	# Convert all component arrays to resource paths
	var _all := all_components.map(map_resource_path)
	var _any := any_components.map(map_resource_path)
	var _exclude := exclude_components.map(map_resource_path)
	
	var result: Array
	
	# If we have all or any components, process those
	if not _all.is_empty() or not _any.is_empty():
		# Handle all_components first if present
		if not _all.is_empty():
			# Performance Optimization: Start with the smallest component set to minimize iterations
			# Get the smallest component set first for better performance
			var smallest_size := INF
			var smallest_component_key := ""
			
			for component in _all:
				var component_entities = component_entity_index.get(component, [])
				var size = component_entities.size()
				if size < smallest_size:
					smallest_size = size
					smallest_component_key = component
			
			# Start with the smallest set and intersect others
			result = component_entity_index.get(smallest_component_key, []).duplicate()
			for component in _all:
				if component != smallest_component_key:
					result = ArrayExtensions.intersect(result, component_entity_index.get(component, []))
					# Early exit if result is empty
					if result.is_empty():
						return []
		
		# Handle any_components
		if not _any.is_empty():
			var any_result := []
			for component in _any:
				any_result.append_array(component_entity_index.get(component, []))
				
			# Remove duplicates
			any_result = Array(any_result.duplicate().reduce(func(accum, item): 
				if not accum.has(item): accum.append(item)
				return accum
			, []))
			
			if result:
				result = ArrayExtensions.intersect(result, any_result)
			else:
				result = any_result
	else:
		# Only if we have no inclusive filters but have exclusions,
		# start with all entities
		if not _exclude.is_empty():
			result = entities.duplicate()
	
	# Handle exclude_components
	if not _exclude.is_empty():
		for component in _exclude:
			var excluded = component_entity_index.get(component, [])
			if not excluded.is_empty():
				result = ArrayExtensions.difference(result, excluded)
	
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
func _on_entity_component_added(entity, component: Variant) -> void:
	# We have to get the script here then resource because we're using an instantiated resource
	_add_entity_to_index(entity, component.get_script().resource_path)
	# Emit Signal
	component_added.emit(entity, component)

## [signal Entity.component_removed] Callback when a component is removed from an entity.[br]
## @param entity The entity that had a component removed.[br]
## @param component_key The resource path of the removed component.
func _on_entity_component_removed(entity, component: Variant) -> void:
	 # We just use resource path here because we pass in a component type
	_remove_entity_from_index(entity, component.resource_path)
	# Emit Signal
	component_removed.emit(entity, component)

## (Optional) Update index when a relationship is added.
func _on_entity_relationship_added(entity: Entity, relationship: Relationship) -> void:
	var key = relationship.relation.resource_path
	if not relationship_entity_index.has(key):
		relationship_entity_index[key] = []
	relationship_entity_index[key].append(entity)
	
	# Index the reverse relationship
	if relationship.target is Entity:
		var rev_key = "reverse_" + key
		if not reverse_relationship_index.has(rev_key):
			reverse_relationship_index[rev_key] = []
		reverse_relationship_index[rev_key].append(relationship.target)
	# Emit Signal
	relationship_added.emit(entity, relationship)

## (Optional) Update index when a relationship is removed.
func _on_entity_relationship_removed(entity: Entity, relationship: Relationship) -> void:
	var key = relationship.relation.resource_path
	if relationship_entity_index.has(key):
		relationship_entity_index[key].erase(entity)
		
	if relationship.target is Entity:
		var rev_key = "reverse_" + key
		if reverse_relationship_index.has(rev_key):
			reverse_relationship_index[rev_key].erase(relationship.target)
	# Emit Signal
	relationship_removed.emit(entity, relationship)
