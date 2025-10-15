## World
##
## Represents the game world in the [_ECS] framework, managing all [Entity]s and [System]s.
##
## The World class handles the addition and removal of [Entity]s and [System]s, and orchestrates the processing of [Entity]s through [System]s each frame.
## The World class also maintains an index mapping of components to entities for efficient querying.
@icon("res://addons/gecs/assets/world.svg")
class_name World
extends Node

#region Signals
## Emitted when an entity is added
signal entity_added(entity: Entity)
signal entity_enabled(entity: Entity)
## Emitted when an entity is removed
signal entity_removed(entity: Entity)
signal entity_disabled(entity: Entity)
## Emitted when a system is added
signal system_added(system: System)
## Emitted when a system is removed
signal system_removed(system: System)
## Emitted when a component is added to an entity
signal component_added(entity: Entity, component: Variant)
## Emitted when a component is removed from an entity
signal component_removed(entity: Entity, component: Variant)
## Emitted when a component property changes on an entity
signal component_changed(
	entity: Entity, component: Variant, property: String, new_value: Variant, old_value: Variant
)
## Emitted when a relationship is added to an entity
signal relationship_added(entity: Entity, relationship: Relationship)
## Emitted when a relationship is removed from an entity
signal relationship_removed(entity: Entity, relationship: Relationship)
## Emitted when the queries are invalidated because of a component change
signal cache_invalidated

#endregion Signals

#region Exported Variables
## Where are all the [Entity] nodes placed in the scene tree?
@export var entity_nodes_root: NodePath
## Where are all the [System] nodes placed in the scene tree?
@export var system_nodes_root: NodePath
## Default serialization config for all entities in this world
@export var default_serialize_config: GECSSerializeConfig

#endregion Exported Variables

#region Public Variables
## All the [Entity]s in the world.
var entities: Array[Entity] = []
## All the [Observer]s in the world.
var observers: Array[Observer] = []
## All the [System]s by group Dictionary[String, Array[System]]
var systems_by_group: Dictionary[String, Array] = {}
## All the [System]s in the world flattened into a single array
var systems: Array[System]:
	get:
		var all_systems: Array[System] = []
		for group in systems_by_group.keys():
			all_systems.append_array(systems_by_group[group])
		return all_systems
## [Component] to [Entity] Index - This stores entities by component for efficient querying.
var component_entity_index: Dictionary = {}
## [Component] to [Enabled Entity] Index - Separate index for enabled entities only
var component_enabled_entity_index: Dictionary = {}
## [Component] to [Disabled Entity] Index - Separate index for disabled entities only
var component_disabled_entity_index: Dictionary = {}
## ID to [Entity] registry - Prevents duplicate IDs and enables fast ID lookups and singleton behavior
var entity_id_registry: Dictionary = {} # String (id) -> Entity
## Pool of QueryBuilder instances to reduce creation overhead
var _query_builder_pool: Array[QueryBuilder] = []
var _pool_size_limit: int = 10

## The [QueryBuilder] instance for this world used to build and execute queries.
## Anytime we request a query we want to connect the cache invalidated signal to the query
## so that all queries are invalidated anytime we emit cache_invalidated.
var query: QueryBuilder:
	get:
		var q: QueryBuilder
		if _query_builder_pool.is_empty():
			q = QueryBuilder.new(self)
			if not cache_invalidated.is_connected(q.invalidate_cache):
				cache_invalidated.connect(q.invalidate_cache)
		else:
			q = _query_builder_pool.pop_back()
			q.clear()
		return q
## Index for relationships to entities (Optional for optimization)
var relationship_entity_index: Dictionary = {}
## Index for reverse relationships (target to source entities)
var reverse_relationship_index: Dictionary = {}
## Logger for the world to only log to a specific domain
var _worldLogger = GECSLogger.new().domain("World")
## Cache for commonly used query results to reduce redundant computations
var _query_result_cache: Dictionary = {}
## Track cache hits for performance monitoring
var _cache_hits: int = 0
var _cache_misses: int = 0

#endregion Public Variables

#region Built-in Virtual Methods
## Called when the World node is ready.
func _ready() -> void:
	#_worldLogger.disabled = true
	initialize()


func _make_nodes_root(name: String) -> Node:
	var node = Node.new()
	node.name = name
	add_child(node)
	return node


## Adds [Entity]s and [System]s from the scene tree to the [World].
## Called when the World node is ready or when we should re-initialize the world from the tree.
func initialize():
	# Initialize default serialize config if not set
	if default_serialize_config == null:
		default_serialize_config = GECSSerializeConfig.new()
	
	# if no entities/systems root node is set create them and use them. This keeps things tidy for debugging
	entity_nodes_root = (
		_make_nodes_root("Entities").get_path() if not entity_nodes_root else entity_nodes_root
	)
	system_nodes_root = (
		_make_nodes_root("Systems").get_path() if not system_nodes_root else system_nodes_root
	)

	# Add systems from scene tree
	var _systems = get_node(system_nodes_root).find_children("*", "System") as Array[System]
	add_systems(_systems, true) # and sort them after they're added
	_worldLogger.debug("_initialize Added Systems from Scene Tree and dep sorted: ", _systems)

	# Add observers from scene tree
	var _observers = get_node(system_nodes_root).find_children("*", "Observer") as Array[Observer]
	add_observers(_observers)
	_worldLogger.debug("_initialize Added Observers from Scene Tree: ", _observers)

	# Add entities from the scene tree
	var _entities = get_node(entity_nodes_root).find_children("*", "Entity") as Array[Entity]
	add_entities(_entities)
	_worldLogger.debug("_initialize Added Entities from Scene Tree: ", _entities)

	assert(GECSEditorDebuggerMessages.world_init(self) if ECS.debug else true, '')


#endregion Built-in Virtual Methods

#region Public Methods
## Called every frame by the [method _ECS.process] to process [System]s.
## [param delta] The time elapsed since the last frame.
## [param group] The string for the group we should run. If empty runs all systems in default "" group.
func process(delta: float, group: String = "") -> void:
	if systems_by_group.has(group):
		for system in systems_by_group[group]:
			if system.active:
				system._handle(delta)
	assert(GECSEditorDebuggerMessages.process_world(delta, group) if ECS.debug else true, '')


## Updates the pause behavior for all systems based on the provided paused state.
## If paused, only systems with PROCESS_MODE_ALWAYS remain active; all others become inactive.
## If unpaused, systems with PROCESS_MODE_DISABLED stay inactive; all others become active.
func update_pause_state(paused: bool) -> void:
	for group_key in systems_by_group.keys():
		for system in systems_by_group[group_key]:
			# Check to see if the system is can process based on the process mode and paused state
			system.paused = not system.can_process()


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
func add_entity(entity: Entity, components = null, add_to_tree = true) -> void:
	# Check for ID collision - if entity with same ID exists, replace it
	var entity_id = GECSIO.uuid() if not entity.id else entity.id
	entity.id = entity_id # update entity with it's new id
	
	if entity_id in entity_id_registry:
		var existing_entity = entity_id_registry[entity_id]
		_worldLogger.debug("ID collision detected, replacing entity: ", existing_entity.name, " with: ", entity.name)
		remove_entity(existing_entity)
	
	# Register this entity's ID
	entity_id_registry[entity_id] = entity

	# ID will auto-generate in _enter_tree if empty, or via property getter on first access
	
	# Update index
	_worldLogger.debug("add_entity Adding Entity to World: ", entity)

	# Connect to entity signals for components so we can track global component state
	if not entity.component_added.is_connected(_on_entity_component_added):
		entity.component_added.connect(_on_entity_component_added)
	if not entity.component_removed.is_connected(_on_entity_component_removed):
		entity.component_removed.connect(_on_entity_component_removed)
	if not entity.relationship_added.is_connected(_on_entity_relationship_added):
		entity.relationship_added.connect(_on_entity_relationship_added)
	if not entity.relationship_removed.is_connected(_on_entity_relationship_removed):
		entity.relationship_removed.connect(_on_entity_relationship_removed)

	# Clear our query cache when new entities are added
	_query_result_cache.clear()
	cache_invalidated.emit()
	
	#  Add the entity to the tree if it's not already there after hooking up the signals
	# This ensures that any _ready methods on the entity or its components are called after setup
	if add_to_tree and not entity.is_inside_tree():
		get_node(entity_nodes_root).add_child(entity)
	
	# add entity to our list
	entities.append(entity)

	# initialize the entity and its components in game only
	if not Engine.is_editor_hint():
		entity._initialize(components if components else [])
	
	entity_added.emit(entity)
	
	# All the entities are ready so we should run the pre-processors now
	for processor in ECS.entity_preprocessors:
		processor.call(entity)

	assert(GECSEditorDebuggerMessages.entity_added(entity) if ECS.debug else true, '')


## Adds multiple entities to the world.[br]
## [param entities] An array of entities to add.
## [param components] The optional list of [Component] to add to the entity.[br]
## [b]Example:[/b]
##      [codeblock]world.add_entities([player_entity, enemy_entity], [component_a])[/codeblock]
func add_entities(_entities: Array, components = null):
	for _entity in _entities:
		add_entity(_entity, components)


## Removes an [Entity] from the world.[br]
## [param entity] The [Entity] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_entity(player_entity)[/codeblock]
func remove_entity(entity) -> void:
	entity = entity as Entity
	
	for processor in ECS.entity_postprocessors:
		processor.call(entity)
	entity_removed.emit(entity)
	_worldLogger.debug("remove_entity Removing Entity: ", entity)
	entities.erase(entity) # FIXME: This doesn't always work for some reason?
	# Update index
	for component_key in entity.components.keys():
		_remove_entity_from_index(entity, component_key)

	# Only disconnect signals if they're actually connected
	if entity.component_added.is_connected(_on_entity_component_added):
		entity.component_added.disconnect(_on_entity_component_added)
	if entity.component_removed.is_connected(_on_entity_component_removed):
		entity.component_removed.disconnect(_on_entity_component_removed)
	if entity.relationship_added.is_connected(_on_entity_relationship_added):
		entity.relationship_added.disconnect(_on_entity_relationship_added)
	if entity.relationship_removed.is_connected(_on_entity_relationship_removed):
		entity.relationship_removed.disconnect(_on_entity_relationship_removed)
	
	# Remove from ID registry
	var entity_id = entity.id
	if entity_id != "" and entity_id in entity_id_registry and entity_id_registry[entity_id] == entity:
		entity_id_registry.erase(entity_id)
	
	
	# Destroy entity normally
	entity.on_destroy()
	entity.queue_free()
	
	# Clear our query cache when component structure changes
	_query_result_cache.clear()
	cache_invalidated.emit()
	assert(GECSEditorDebuggerMessages.entity_removed(entity) if ECS.debug else true, '')


## Removes an Array of [Entity] from the world.[br]
## [param entity] The Array of [Entity] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_entities([player_entity, other_entity])[/codeblock]
func remove_entities(_entities: Array) -> void:
	for _entity in _entities:
		remove_entity(_entity)


## Disable an [Entity] from the world. Disabled entities don't run process or physics,[br]
## are hidden and removed the entities list and the[br]
## [param entity] The [Entity] to disable.[br]
## [b]Example:[/b]
##      [codeblock]world.disable_entity(player_entity)[/codeblock]
func disable_entity(entity) -> Entity:
	entity = entity as Entity
	entity.enabled = false # This will trigger _on_entity_enabled_changed via setter
	entity_disabled.emit(entity)
	_worldLogger.debug("disable_entity Disabling Entity: ", entity)

	# Move entity from enabled index to disabled index
	_move_entity_to_disabled_index(entity)

	entity.component_added.disconnect(_on_entity_component_added)
	entity.component_removed.disconnect(_on_entity_component_removed)
	entity.relationship_added.disconnect(_on_entity_relationship_added)
	entity.relationship_removed.disconnect(_on_entity_relationship_removed)
	entity.on_disable()
	entity.set_process(false)
	entity.set_physics_process(false)
	# Clear our query cache when component structure changes
	_query_result_cache.clear()
	cache_invalidated.emit()
	assert(GECSEditorDebuggerMessages.entity_disabled(entity) if ECS.debug else true, '')
	return entity


## Disable an Array of [Entity] from the world. Disabled entities don't run process or physics,[br]
## are hidden and removed the entities list[br]
## [param entity] The [Entity] to disable.[br]
## [b]Example:[/b]
##      [codeblock]world.disable_entities([player_entity, other_entity])[/codeblock]
func disable_entities(_entities: Array) -> void:
	for _entity in _entities:
		disable_entity(_entity)

## Enables a single [Entity] to the world.[br]
## [param entity] The [Entity] to enable.[br]
## [param components] The optional list of [Component] to add to the entity.[br]
## [b]Example:[/b]
## [codeblock]
## # enable just an entity
## world.enable_entity(player_entity)
## # enable an entity with some components
## world.enable_entity(other_entity, [component_a, component_b])
## [/codeblock]
func enable_entity(entity: Entity, components = null) -> void:
	# Update index
	_worldLogger.debug("enable_entity Enabling Entity to World: ", entity)
	entity.enabled = true # This will trigger _on_entity_enabled_changed via setter
	entity_enabled.emit(entity)

	# Move entity from disabled index to enabled index
	_move_entity_to_enabled_index(entity)

	# Connect to entity signals for components so we can track global component state
	if not entity.component_added.is_connected(_on_entity_component_added):
		entity.component_added.connect(_on_entity_component_added)
	if not entity.component_removed.is_connected(_on_entity_component_removed):
		entity.component_removed.connect(_on_entity_component_removed)
	if not entity.relationship_added.is_connected(_on_entity_relationship_added):
		entity.relationship_added.connect(_on_entity_relationship_added)
	if not entity.relationship_removed.is_connected(_on_entity_relationship_removed):
		entity.relationship_removed.connect(_on_entity_relationship_removed)

	if components:
		entity.add_components(components)

	entity.set_process(true)
	entity.set_physics_process(true)
	entity.on_enable()
	# Clear our query cache when component structure changes
	_query_result_cache.clear()
	cache_invalidated.emit()
	assert(GECSEditorDebuggerMessages.entity_enabled(entity) if ECS.debug else true, '')


## Find an entity by its persistent ID
## [param id] The id to search for
## [return] The Entity with matching ID, or null if not found
func get_entity_by_id(id: String) -> Entity:
	return entity_id_registry.get(id, null)


## Check if an entity with the given ID exists in the world
## [param id] The id to check
## [return] true if an entity with this ID exists, false otherwise
func has_entity_with_id(id: String) -> bool:
	return id in entity_id_registry


#region Systems


## Adds a single system to the world.
##
## [param system] The system to add.
##
## [b]Example:[/b]
##      [codeblock]world.add_system(movement_system)[/codeblock]
func add_system(system: System, topo_sort: bool = false) -> void:
	if not system.is_inside_tree():
		get_node(system_nodes_root).add_child(system)
	_worldLogger.trace("add_system Adding System: ", system)
	if not systems_by_group.has(system.group):
		systems_by_group[system.group] = []
	systems_by_group[system.group].push_back(system)
	system_added.emit(system)
	system.setup()
	if topo_sort:
		ArrayExtensions.topological_sort(systems_by_group)
	assert(GECSEditorDebuggerMessages.system_added(system) if ECS.debug else true, '')


## Adds multiple systems to the world.
##
## [param systems] An array of systems to add.
##
## [b]Example:[/b]
##      [codeblock]world.add_systems([movement_system, render_system])[/codeblock]
func add_systems(_systems: Array, topo_sort: bool = false):
	for _system in _systems:
		add_system(_system)
	# After we add them all sort them
	if topo_sort:
		ArrayExtensions.topological_sort(systems_by_group)


## Removes a [System] from the world.[br]
## [param system] The [System] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_system(movement_system)[/codeblock]
func remove_system(system, topo_sort: bool = false) -> void:
	_worldLogger.debug("remove_system Removing System: ", system)
	systems_by_group[system.group].erase(system)
	if systems_by_group[system.group].size() == 0:
		systems_by_group.erase(system.group)
	system_removed.emit(system)
	# Update index
	system.queue_free()
	if topo_sort:
		ArrayExtensions.topological_sort(systems_by_group)
	assert(GECSEditorDebuggerMessages.system_removed(system) if ECS.debug else true, '')


## Removes an Array of [System] from the world.[br]
## [param system] The Array of [System] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_systems([movement_system, other_system])[/codeblock]
func remove_systems(_systems: Array, topo_sort: bool = false) -> void:
	for _system in _systems:
		remove_system(_system)
	if topo_sort:
		ArrayExtensions.topological_sort(systems_by_group)


## Removes all systems in a group from the world.[br]
## [param group] The group name of the systems to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_system_group("Gameplay")[/codeblock]
func remove_system_group(group: String, topo_sort: bool = false) -> void:
	if systems_by_group.has(group):
		for system in systems_by_group[group]:
			remove_system(system)
		if topo_sort:
			ArrayExtensions.topological_sort(systems_by_group)


## Removes all [Entity]s and [System]s from the world.[br]
## [param should_free] Optionally frees the world node by default
## [param keep] A list of entities that should be kept in the world
func purge(should_free = true, keep := []) -> void:
	# Get rid of all entities
	_worldLogger.debug("Purging Entities", entities)
	for entity in entities.duplicate().filter(func(x): return not keep.has(x)):
		remove_entity(entity)

	# Clear relationship indexes after purging entities
	relationship_entity_index.clear()
	reverse_relationship_index.clear()
	_worldLogger.debug("Cleared relationship indexes after purge")

	# Purge all systems
	_worldLogger.debug("Purging All Systems")
	for group_key in systems_by_group.keys():
		for system in systems_by_group[group_key].duplicate():
			remove_system(system)

	# Purge all observers
	_worldLogger.debug("Purging Observers", observers)
	for observer in observers.duplicate():
		remove_observer(observer)

	# remove itself
	if should_free:
		queue_free()


## Executes a query to retrieve entities based on component criteria.[br]
## [param all_components] [Component]s that [Entity]s must have all of.[br]
## [param any_components] [Component]s that [Entity]s must have at least one of.[br]
## [param exclude_components] [Component]s that [Entity]s must not have.[br]
## [param returns] An [Array] of [Entity]s that match the query.[br]
## [br]
## Performance Optimization:[br]
## When checking for all_components, the system first identifies the component with the smallest[br]
## set of entities and starts with that set. This significantly reduces the number of comparisons needed,[br]
## as we only need to check the smallest possible set of entities against other components.

#endregion Systems

func _query(all_components = [], any_components = [], exclude_components = [], enabled_filter = null) -> Array:
	# Early return if no components specified
	if all_components.is_empty() and any_components.is_empty() and exclude_components.is_empty():
		return entities

	# Check world-level cache first
	var cache_key = _generate_query_cache_key(all_components, any_components, exclude_components)
	if _query_result_cache.has(cache_key):
		_cache_hits += 1
		# Return cached array directly - user must not modify returned array!
		# This is standard ECS practice: query results are read-only views
		return _query_result_cache[cache_key]

	_cache_misses += 1
	var map_resource_path = func(x): return x.resource_path
	# Convert all component arrays to resource paths
	var _all := all_components.map(map_resource_path)
	var _any := any_components.map(map_resource_path)
	var _exclude := exclude_components.map(map_resource_path)

	# Choose the appropriate index based on enabled_filter
	var active_index: Dictionary
	if enabled_filter == true:
		active_index = component_enabled_entity_index
	elif enabled_filter == false:
		active_index = component_disabled_entity_index
	else:
		active_index = component_entity_index

	var result: Set

	# If we have all or any components, process those
	if not _all.is_empty() or not _any.is_empty():
		# Handle all_components first if present
		if not _all.is_empty():
			# Performance Optimization: Start with the smallest component set to minimize iterations
			# Get the smallest component set first for better performance
			var smallest_size := INF
			var smallest_component_key := ""

			for component in _all:
				var component_entities = active_index.get(component, Set.new())
				var size = component_entities.size()
				# Early exit if any required component has no entities
				if size == 0:
					return []
				if size < smallest_size:
					smallest_size = size
					smallest_component_key = component

			# Start with the smallest set and intersect others
			result = active_index.get(smallest_component_key, Set.new())
			for component in _all:
				# Early exit if result is empty
				if result.is_empty():
					return []
				if component == smallest_component_key:
					continue
				result = result.intersect(active_index.get(component, Set.new()))

		# Handle any_components
		if not _any.is_empty():
			var any_result: Set = Set.new()
			# Start with first component's entities
			if _any.size() > 0:
				any_result = active_index.get(_any[0], Set.new())
				# Union with remaining components
				for i in range(1, _any.size()):
					var entities_with_component = active_index.get(_any[i], Set.new())
					any_result = any_result.union(entities_with_component)

			if result:
				result = result.intersect(any_result)
			else:
				result = any_result
	else:
		# Only if we have no inclusive filters but have exclusions,
		# start with all entities
		if not _exclude.is_empty():
			result = Set.new(entities)

	# Handle exclude_components
	if not _exclude.is_empty():
		for component in _exclude:
			var excluded = active_index.get(component, Set.new())
			if not excluded.is_empty():
				result = result.difference(excluded)

	# Cache the result for future queries
	_query_result_cache[cache_key] = result.to_array()
	# Return cached array directly - user must not modify returned array!
	return _query_result_cache[cache_key]


#region Index Management Functions


## Adds an entity to the component index.[br]
## [param entity] The entity to index.[br]
## [param component_key] The component's resource path.
func _add_entity_to_index(entity: Entity, component_key: String) -> void:
	# Add to main index (all entities)
	if not component_entity_index.has(component_key):
		component_entity_index[component_key] = Set.new()
	var entity_list = component_entity_index[component_key]
	entity_list.add(entity)

	# Add to enabled/disabled index based on entity state
	if entity.enabled:
		if not component_enabled_entity_index.has(component_key):
			component_enabled_entity_index[component_key] = Set.new()
		component_enabled_entity_index[component_key].add(entity)
	else:
		if not component_disabled_entity_index.has(component_key):
			component_disabled_entity_index[component_key] = Set.new()
		component_disabled_entity_index[component_key].add(entity)


## Removes an entity from the component index.[br]
## [param entity] The entity to remove.[br]
## [param component_key] The component's resource path.
func _remove_entity_from_index(entity, component_key: String) -> void:
	# Remove from main index
	if component_entity_index.has(component_key):
		var entity_list: Set = component_entity_index[component_key]
		entity_list.erase(entity)
		if entity_list.size() == 0:
			component_entity_index.erase(component_key)

	# Remove from enabled index
	if component_enabled_entity_index.has(component_key):
		var enabled_list: Set = component_enabled_entity_index[component_key]
		enabled_list.erase(entity)
		if enabled_list.size() == 0:
			component_enabled_entity_index.erase(component_key)

	# Remove from disabled index
	if component_disabled_entity_index.has(component_key):
		var disabled_list: Set = component_disabled_entity_index[component_key]
		disabled_list.erase(entity)
		if disabled_list.size() == 0:
			component_disabled_entity_index.erase(component_key)


## Moves an entity from disabled index to enabled index for all its components.[br]
## Called when an entity is enabled.[br]
## [param entity] The entity being enabled.
func _move_entity_to_enabled_index(entity: Entity) -> void:
	for component_key in entity.components.keys():
		# Remove from disabled index
		if component_disabled_entity_index.has(component_key):
			var disabled_list: Set = component_disabled_entity_index[component_key]
			disabled_list.erase(entity)
			if disabled_list.size() == 0:
				component_disabled_entity_index.erase(component_key)

		# Add to enabled index
		if not component_enabled_entity_index.has(component_key):
			component_enabled_entity_index[component_key] = Set.new()
		component_enabled_entity_index[component_key].add(entity)


## Moves an entity from enabled index to disabled index for all its components.[br]
## Called when an entity is disabled.[br]
## [param entity] The entity being disabled.
func _move_entity_to_disabled_index(entity: Entity) -> void:
	for component_key in entity.components.keys():
		# Remove from enabled index
		if component_enabled_entity_index.has(component_key):
			var enabled_list: Set = component_enabled_entity_index[component_key]
			enabled_list.erase(entity)
			if enabled_list.size() == 0:
				component_enabled_entity_index.erase(component_key)

		# Add to disabled index
		if not component_disabled_entity_index.has(component_key):
			component_disabled_entity_index[component_key] = Set.new()
		component_disabled_entity_index[component_key].add(entity)


#endregion Index Management Functions

#region Signal Callbacks


## [signal Entity.component_added] Callback when a component is added to an entity.[br]
## [param entity] The entity that had a component added.[br]
## [param component] The resource path of the added component.
func _on_entity_component_added(entity: Entity, component: Resource) -> void:
	# We have to get the script here then resource because we're using an instantiated resource
	_add_entity_to_index(entity, component.get_script().resource_path)
	
	# Clear query cache when components are added
	_query_result_cache.clear()
	cache_invalidated.emit()
	
	# Emit Signal
	component_added.emit(entity, component)

	# Handle observers for component added
	_handle_observer_component_added(entity, component)

	# Watch for propety changes to the component
	if not entity.component_property_changed.is_connected(_on_entity_component_property_change):
		# Connect to the component's property changed signal
		# This allows us to track changes to properties on the component
		# and notify observers
		entity.component_property_changed.connect(_on_entity_component_property_change)

	assert(GECSEditorDebuggerMessages.entity_component_added(entity, component) if ECS.debug else true, '')


## Called when a component property changes through signals called on the components and connected to.[br]
## in the _ready method.[br]
## [param entity] The [Entity] with the component change.[br]
## [param component] The [Component] that changed.[br]
## [param property_name] The name of the property that changed.[br]
## [param old_value] The old value of the property.[br]
## [param new_value] The new value of the property.[br]
func _on_entity_component_property_change(
	entity: Entity,
	component: Resource,
	property_name: String,
	old_value: Variant,
	new_value: Variant
) -> void:
	# Notify the World to trigger observers
	_handle_observer_component_changed(entity, component, property_name, new_value, old_value)
	# Clear our query cache when component structure changes
	_query_result_cache.clear()
	cache_invalidated.emit()
	# Send the message to the debugger if we're in debug
	assert(GECSEditorDebuggerMessages.entity_component_property_changed(
		entity, component, property_name, old_value, new_value
	) if ECS.debug else true, '')


## [signal Entity.component_removed] Callback when a component is removed from an entity.[br]
## [param entity] The entity that had a component removed.[br]
## [param component] The resource path of the removed component.
func _on_entity_component_removed(entity, component: Resource) -> void:
	# We remove components immediately so this was called on the entity all we do is pass signal along
	# Emit Signal
	component_removed.emit(entity, component)

	# Handle observers for component removed
	_handle_observer_component_removed(entity, component)
	
	# Clear query cache when components are removed
	_query_result_cache.clear()
	cache_invalidated.emit()

	assert(GECSEditorDebuggerMessages.entity_component_removed(entity, component) if ECS.debug else true, '')
	

## (Optional) Update index when a relationship is added.
func _on_entity_relationship_added(entity: Entity, relationship: Relationship) -> void:
	var key = relationship.relation.resource_path
	if not relationship_entity_index.has(key):
		relationship_entity_index[key] = []
	relationship_entity_index[key].append(entity)

	# Index the reverse relationship
	if is_instance_valid(relationship.target) and relationship.target is Entity:
		var rev_key = "reverse_" + key
		if not reverse_relationship_index.has(rev_key):
			reverse_relationship_index[rev_key] = []
		reverse_relationship_index[rev_key].append(relationship.target)
	
	# Clear query cache when relationships are added
	_query_result_cache.clear()
	cache_invalidated.emit()
	
	# Emit Signal
	relationship_added.emit(entity, relationship)
	assert(GECSEditorDebuggerMessages.entity_relationship_added(entity, relationship) if ECS.debug else true, '')


## (Optional) Update index when a relationship is removed.
func _on_entity_relationship_removed(entity: Entity, relationship: Relationship) -> void:
	var key = relationship.relation.resource_path
	if relationship_entity_index.has(key):
		relationship_entity_index[key].erase(entity)

	if is_instance_valid(relationship.target) and relationship.target is Entity:
		var rev_key = "reverse_" + key
		if reverse_relationship_index.has(rev_key):
			reverse_relationship_index[rev_key].erase(relationship.target)
	
	# Clear query cache when relationships are removed
	_query_result_cache.clear()
	cache_invalidated.emit()
	
	# Emit Signal
	relationship_removed.emit(entity, relationship)
	assert(GECSEditorDebuggerMessages.entity_relationship_removed(entity, relationship) if ECS.debug else true, '')


## Adds a single [Observer] to the [World].
## [param observer] The [Observer] to add.
## [b]Example:[/b]
##      [codeblock]world.add_observer(health_change_system)[/codeblock]
func add_observer(_observer: Observer) -> void:
	# Verify the system has a valid watch component
	_observer.watch() # Just call to validate it returns a component
	if not _observer.is_inside_tree():
		get_node(system_nodes_root).add_child(_observer)
	_worldLogger.trace("add_observer Adding Observer: ", _observer)
	observers.append(_observer)

	# Initialize the query builder for the observer
	_observer.q = QueryBuilder.new(self)

	# Verify the system has a valid watch component
	_observer.watch() # Just call to validate it returns a component


## Adds multiple [Observer]s to the [World].
## [param observers] An array of [Observer]s to add.
## [b]Example:[/b]
##      [codeblock]world.add_observers([health_system, damage_system])[/codeblock]
func add_observers(_observers: Array):
	for _observer in _observers:
		add_observer(_observer)


## Removes an [Observer] from the [World].
## [param observer] The [Observer] to remove.
## [b]Example:[/b]
##      [codeblock]world.remove_observer(health_system)[/codeblock]
func remove_observer(observer: Observer) -> void:
	_worldLogger.debug("remove_observer Removing Observer: ", observer)
	observers.erase(observer)
	# if ECS.debug:
	# 	# Don't use system_removed as it expects a System not ReactiveSystem
	# 	GECSEditorDebuggerMessages.exit_world()  # Just send a general update
	observer.queue_free()


## Handle component property changes and notify observers
## [param entity] The entity with the component change
## [param component] The component that changed
## [param property] The property name that changed
## [param new_value] The new value of the property
## [param old_value] The previous value of the property
func handle_component_changed(
	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
) -> void:
	# Emit the general signal
	component_changed.emit(entity, component, property, new_value, old_value)

	# Find observers watching for this component and notify them
	_handle_observer_component_changed(entity, component, property, new_value, old_value)


## Notify observers when a component is added
func _handle_observer_component_added(entity: Entity, component: Resource) -> void:
	for reactive_system in observers:
		# Get the component that this system is watching
		var watch_component = reactive_system.watch()
		if (
			watch_component
			and component and component.get_script()
			and watch_component.resource_path == component.get_script().resource_path
		):
			# Check if the entity matches the system's query
			var query_builder = reactive_system.match()
			var matches = true

			if query_builder:
				# Use the _query method instead of trying to use query as a function
				var entities_matching = _query(
					query_builder._all_components,
					query_builder._any_components,
					query_builder._exclude_components
				)
				# Check if our entity is in the result set
				matches = entities_matching.has(entity)

			if matches:
				reactive_system.on_component_added(entity, component)


## Notify observers when a component is removed
func _handle_observer_component_removed(entity: Entity, component: Resource) -> void:
	for reactive_system in observers:
		# Get the component that this system is watching
		var watch_component = reactive_system.watch()
		if watch_component and watch_component.resource_path == component.resource_path:
			# For removal, we don't check the query since the component is already removed
			# Just notify the system
			reactive_system.on_component_removed(entity, component)


## Notify observers when a component property changes
func _handle_observer_component_changed(
	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
) -> void:
	for reactive_system in observers:
		# Get the component that this system is watching
		var watch_component = reactive_system.watch()
		if (
			watch_component
			and component and component.get_script()
			and watch_component.resource_path == component.get_script().resource_path
		):
			# Check if the entity matches the system's query
			var query_builder = reactive_system.match()
			var matches = true

			if query_builder:
				# Use the _query method instead of trying to use query as a function
				var entities_matching = _query(
					query_builder._all_components,
					query_builder._any_components,
					query_builder._exclude_components
				)
				# Check if our entity is in the result set
				matches = entities_matching.has(entity)

			if matches:
				reactive_system.on_component_changed(
					entity, component, property, new_value, old_value
				)

#endregion Signal Callbacks

#endregion Public Methods

#region Utility Methods
## Get performance statistics for cache usage
func get_cache_stats() -> Dictionary:
	var total_requests = _cache_hits + _cache_misses
	var hit_rate = 0.0 if total_requests == 0 else float(_cache_hits) / float(total_requests)
	return {
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"hit_rate": hit_rate,
		"cached_queries": _query_result_cache.size()
	}


## Reset cache statistics
func reset_cache_stats() -> void:
	_cache_hits = 0
	_cache_misses = 0


## Return a QueryBuilder instance to the pool for reuse
func _return_query_builder_to_pool(query_builder: QueryBuilder) -> void:
	if _query_builder_pool.size() < _pool_size_limit:
		query_builder.clear()
		_query_builder_pool.append(query_builder)


## Generate a cache key for query parameters
## 
## Uses a polynomial rolling hash algorithm combined with XOR to create stable,
## collision-resistant cache keys from component instance IDs. This approach
## ensures that queries with the same components produce identical cache keys
## while different component combinations produce distinct keys.
##
## Algorithm details:
## - Each component type (all/any/exclude) uses a different prime multiplier
## - Instance IDs are multiplied by their respective prime and XORed into the hash
## - XOR operations preserve commutativity (order doesn't matter within each array)
## - Different primes ensure separation between component type domains
##
## Time complexity: O(n) where n is total number of components
## Space complexity: O(1)
##
## References:
## - Rolling hash: https://en.wikipedia.org/wiki/Rolling_hash
## - Universal hashing: https://en.wikipedia.org/wiki/Universal_hashing
## - Hash functions: https://en.wikipedia.org/wiki/Hash_function
func _generate_query_cache_key(all_components: Array, any_components: Array, exclude_components: Array) -> int:
	# Direct instance ID access with XOR for clean, fast hashing
	# Use different prime multipliers to distinguish component types
	var h = 0
	
	# Process all arrays with different primes for uniqueness
	# all_components: prime 31 (commonly used in string hashing)
	for comp in all_components:
		h ^= comp.get_instance_id() * 31
	
	# any_components: prime 37 (ensures domain separation)
	for comp in any_components:
		h ^= comp.get_instance_id() * 37
	
	# exclude_components: prime 41 (further domain separation)
	for comp in exclude_components:
		h ^= comp.get_instance_id() * 41
	
	return h


#endregion Utility Methods
