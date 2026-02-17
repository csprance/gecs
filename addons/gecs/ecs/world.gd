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
## ID to [Entity] registry - Prevents duplicate IDs and enables fast ID lookups and singleton behavior
var entity_id_registry: Dictionary = {}  # String (id) -> Entity
## ARCHETYPE STORAGE - Entity storage by component signature for O(1) queries
## Maps archetype signature (FNV-1a hash) -> Archetype instance
var archetypes: Dictionary = {}  # int -> Archetype
## Fast lookup: Entity -> its current Archetype
var entity_to_archetype: Dictionary = {}  # Entity -> Archetype
## The [QueryBuilder] instance for this world used to build and execute queries.
## Anytime we request a query we want to connect the cache invalidated signal to the query
## so that all queries are invalidated anytime we emit cache_invalidated.
var query: QueryBuilder:
	get:
		var q: QueryBuilder = QueryBuilder.new(self)
		if not cache_invalidated.is_connected(q.invalidate_cache):
			cache_invalidated.connect(q.invalidate_cache)
		return q
## Index for relationships to entities (Optional for optimization)
var relationship_entity_index: Dictionary = {}
## Index for reverse relationships (target to source entities)
var reverse_relationship_index: Dictionary = {}
## Logger for the world to only log to a specific domain
var _worldLogger = GECSLogger.new().domain("World")
## Cache for commonly used query results - stores matching archetypes, not entities
## This dramatically reduces cache invalidation since archetypes are stable
var _query_archetype_cache: Dictionary = {}  # query_sig -> Array[Archetype]
## Track cache hits for performance monitoring
var _cache_hits: int = 0
var _cache_misses: int = 0
## Track cache invalidations for debugging
var _cache_invalidation_count: int = 0
var _cache_invalidation_reasons: Dictionary = {}  # reason -> count
## Global cache: resource_path -> Script (loaded once, reused forever)
var _component_script_cache: Dictionary = {}  # String -> Script
## OPTIMIZATION: Flag to control cache invalidation during batch operations
var _should_invalidate_cache: bool = true
## Frame + accumulated performance metrics (debug-only)
var _perf_metrics := {"frame": {}, "accum": {}}  # Per-frame aggregated timings  # Long-lived totals (cleared manually)
## Queue of systems waiting for setup after ECS.world is assigned
var _deferred_setup_systems: Array[System] = []


## Internal perf helper (debug only)
func perf_mark(key: String, duration_usec: int, extra: Dictionary = {}) -> void:
	if not ECS.debug:
		return
	# Aggregate per frame
	var entry = _perf_metrics.frame.get(key, {"count": 0, "time_usec": 0})
	entry.count += 1
	entry.time_usec += duration_usec
	for k in extra.keys():
		# Attach/overwrite ancillary data (last value wins)
		entry[k] = extra[k]
	_perf_metrics.frame[key] = entry
	# Accumulate lifetime totals
	var accum_entry = _perf_metrics.accum.get(key, {"count": 0, "time_usec": 0})
	accum_entry.count += 1
	accum_entry.time_usec += duration_usec
	_perf_metrics.accum[key] = accum_entry


## Reset per-frame metrics (called at world.process start)
func perf_reset_frame() -> void:
	if ECS.debug:
		_perf_metrics.frame.clear()


## Get a copy of current frame metrics
func perf_get_frame_metrics() -> Dictionary:
	return _perf_metrics.frame.duplicate(true)


## Get a copy of accumulated metrics
func perf_get_accum_metrics() -> Dictionary:
	return _perf_metrics.accum.duplicate(true)


## Reset accumulated metrics
func perf_reset_accum() -> void:
	if ECS.debug:
		_perf_metrics.accum.clear()


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

	# Add systems from scene tree - setup will be deferred until ECS.world is set
	var _systems = get_node(system_nodes_root).find_children("*", "System") as Array[System]
	add_systems(_systems, true)  # and sort them after they're added
	_worldLogger.debug("_initialize Added Systems from Scene Tree and dep sorted: ", _systems)

	# Add observers from scene tree
	var _observers = get_node(system_nodes_root).find_children("*", "Observer") as Array[Observer]
	add_observers(_observers)
	_worldLogger.debug("_initialize Added Observers from Scene Tree: ", _observers)

	# Add entities from the scene tree
	var _entities = get_node(entity_nodes_root).find_children("*", "Entity") as Array[Entity]
	add_entities(_entities)
	_worldLogger.debug("_initialize Added Entities from Scene Tree: ", _entities)

	if ECS.debug:
		assert(GECSEditorDebuggerMessages.world_init(self), "")
		# Register debugger message handler for entity polling
		if (
			not Engine.is_editor_hint()
			and OS.has_feature("editor")
			and not EngineDebugger.has_capture("gecs")
		):
			EngineDebugger.register_message_capture("gecs", _handle_debugger_message)


## Finalize deferred system setup after ECS.world is set.
## All systems defer their setup() until this method is called to ensure
## setup() methods can safely access both _world and ECS.world.
func finalize_system_setup() -> void:
	if _deferred_setup_systems.is_empty():
		return

	_worldLogger.debug(
		"finalize_system_setup Executing deferred setup for ",
		_deferred_setup_systems.size(),
		" systems"
	)
	for system in _deferred_setup_systems:
		system._internal_setup()  # Now safe to call setup() with ECS.world available
		_worldLogger.trace("finalize_system_setup Completed setup for system: ", system)

	_deferred_setup_systems.clear()
	_worldLogger.debug("finalize_system_setup All deferred system setups completed")


#endregion Built-in Virtual Methods


#region Public Methods
## Called every frame by the [method _ECS.process] to process [System]s.
## [param delta] The time elapsed since the last frame.
## [param group] The string for the group we should run. If empty runs all systems in default "" group.
func process(delta: float, group: String = "") -> void:
	# PERF: Reset frame metrics at start of processing step
	perf_reset_frame()
	if systems_by_group.has(group):
		var system_index = 0
		for system in systems_by_group[group]:
			if system.active:
				system._handle(delta)
				if ECS.debug:
					# Add execution order to last run data
					system.lastRunData["execution_order"] = system_index
					assert(
						GECSEditorDebuggerMessages.system_last_run_data(system, system.lastRunData),
						""
					)
					system_index += 1

		# Flush PER_GROUP command buffers after all systems in the group complete
		for system in systems_by_group[group]:
			if system.command_buffer_flush_mode == "PER_GROUP" and system.has_pending_commands():
				system.cmd.execute()
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.process_world(delta, group), "")


## Manually flush all command buffers with MANUAL flush mode.[br]
## This executes all queued commands from systems that use command_buffer_flush_mode = "MANUAL".[br]
## [b]Example:[/b]
## [codeblock]
## func _process(delta):
##     ECS.process(delta, "physics")
##     ECS.process(delta, "render")
##     ECS.world.flush_command_buffers()  # Execute all MANUAL commands at once
## [/codeblock]
func flush_command_buffers() -> void:
	for group_key in systems_by_group.keys():
		for system in systems_by_group[group_key]:
			if system.command_buffer_flush_mode == "MANUAL" and system.has_pending_commands():
				system.cmd.execute()


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
	entity.id = entity_id  # update entity with it's new id

	if entity_id in entity_id_registry:
		var existing_entity = entity_id_registry[entity_id]
		_worldLogger.debug(
			"ID collision detected, replacing entity: ",
			existing_entity.name,
			" with: ",
			entity.name
		)
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

	#  Add the entity to the tree if it's not already there after hooking up the signals
	# This ensures that any _ready methods on the entity or its components are called after setup
	if add_to_tree and not entity.is_inside_tree():
		get_node(entity_nodes_root).add_child(entity)

	# add entity to our list
	entities.append(entity)

	# OPTIMIZATION: Suppress cache invalidation during entity initialization.
	# _add_entity_to_archetype and each component_added signal would each
	# invalidate the cache individually. Defer to a single invalidation at the end.
	var original_invalidate = _should_invalidate_cache
	_should_invalidate_cache = false

	# ARCHETYPE: Add entity to archetype system BEFORE initialization
	# Start with empty archetype, then move as components are added
	_add_entity_to_archetype(entity)

	# initialize the entity and its components in game only
	# This will trigger component_added signals which move the entity to the right archetype
	if not Engine.is_editor_hint():
		entity._initialize(components if components else [])

	# Re-enable and perform a single cache invalidation for the entire add_entity operation
	_should_invalidate_cache = original_invalidate
	_invalidate_cache("entity_added")

	entity_added.emit(entity)

	# All the entities are ready so we should run the pre-processors now
	for processor in ECS.entity_preprocessors:
		processor.call(entity)

	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_added(entity, add_to_tree), "")


## Adds multiple entities to the world.[br]
## [param entities] An array of entities to add.
## [param components] The optional list of [Component] to add to the entity.[br]
## [b]Example:[/b]
##      [codeblock]world.add_entities([player_entity, enemy_entity], [component_a])[/codeblock]
func add_entities(_entities: Array, components = null):
	# OPTIMIZATION: Batch processing to reduce cache invalidations
	# Temporarily disable cache invalidation during batch, then invalidate once at the end
	var original_invalidate = _should_invalidate_cache
	_should_invalidate_cache = false

	var new_archetypes_created = false
	var initial_archetype_count = archetypes.size()

	# Process all entities
	for _entity in _entities:
		add_entity(_entity, components)

	# Check if any new archetypes were created
	if archetypes.size() > initial_archetype_count:
		new_archetypes_created = true

	# Re-enable cache invalidation and invalidate once if needed
	_should_invalidate_cache = original_invalidate
	if new_archetypes_created:
		_invalidate_cache("batch_add_entities")


## Removes an [Entity] from the world.[br]
## [param entity] The [Entity] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_entity(player_entity)[/codeblock]
func remove_entity(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	entity = entity as Entity

	for processor in ECS.entity_postprocessors:
		processor.call(entity)
	entity_removed.emit(entity)
	_worldLogger.debug("remove_entity Removing Entity: ", entity)
	var erase_idx = entities.find(entity)
	if erase_idx >= 0:
		entities.remove_at(erase_idx)
	else:
		_worldLogger.warning("remove_entity: entity not found in entities array: ", entity)

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
	if (
		entity_id != ""
		and entity_id in entity_id_registry
		and entity_id_registry[entity_id] == entity
	):
		entity_id_registry.erase(entity_id)

	# ARCHETYPE: Remove entity from archetype system (parallel)
	_remove_entity_from_archetype(entity)

	# Destroy entity normally
	entity.on_destroy()
	if entity.is_inside_tree():
		entity.queue_free()
	else:
		entity.free()

	# Notify debugger before freeing (entity must still be valid)
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_removed(entity_id), "")

## Removes an Array of [Entity] from the world.[br]
## [param entity] The Array of [Entity] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_entities([player_entity, other_entity])[/codeblock]
func remove_entities(_entities: Array) -> void:
	# OPTIMIZATION: Batch processing to reduce cache invalidations
	# Temporarily disable cache invalidation during batch, then invalidate once at the end
	var original_invalidate = _should_invalidate_cache
	_should_invalidate_cache = false

	# Process all entities
	for _entity in _entities:
		remove_entity(_entity)

	# Re-enable cache invalidation and always invalidate when entities are removed
	# QueryBuilder caches execute() results, so any entity removal requires cache invalidation
	_should_invalidate_cache = original_invalidate
	_invalidate_cache("batch_remove_entities")


## Disable an [Entity] from the world. Disabled entities don't run process or physics,[br]
## are hidden and removed the entities list and the[br]
## [param entity] The [Entity] to disable.[br]
## [b]Example:[/b]
##      [codeblock]world.disable_entity(player_entity)[/codeblock]
func disable_entity(entity) -> Entity:
	entity = entity as Entity
	entity.enabled = false  # This will trigger _on_entity_enabled_changed via setter
	entity_disabled.emit(entity)
	_worldLogger.debug("disable_entity Disabling Entity: ", entity)

	if entity.component_added.is_connected(_on_entity_component_added):
		entity.component_added.disconnect(_on_entity_component_added)
	if entity.component_removed.is_connected(_on_entity_component_removed):
		entity.component_removed.disconnect(_on_entity_component_removed)
	if entity.relationship_added.is_connected(_on_entity_relationship_added):
		entity.relationship_added.disconnect(_on_entity_relationship_added)
	if entity.relationship_removed.is_connected(_on_entity_relationship_removed):
		entity.relationship_removed.disconnect(_on_entity_relationship_removed)
	entity.on_disable()
	entity.set_process(false)
	entity.set_physics_process(false)
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_disabled(entity), "")
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
	entity.enabled = true  # This will trigger _on_entity_enabled_changed via setter
	entity_enabled.emit(entity)

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
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_enabled(entity), "")


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

	# Give the system a reference to this world
	system._world = self

	if not systems_by_group.has(system.group):
		systems_by_group[system.group] = []
	systems_by_group[system.group].push_back(system)
	system_added.emit(system)

	# ALWAYS DEFER SETUP: Queue system setup until ECS.world is assigned
	# This ensures setup() methods can safely access ECS.world
	_deferred_setup_systems.append(system)
	_worldLogger.trace("add_system Deferring setup for system: ", system)

	if topo_sort:
		ArrayExtensions.topological_sort(systems_by_group)
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.system_added(system), "")


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
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.system_removed(system), "")


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

	# ARCHETYPE: Clear archetype system
	# First, break circular references by clearing edges
	for archetype in archetypes.values():
		archetype.add_edges.clear()
		archetype.remove_edges.clear()
	archetypes.clear()
	entity_to_archetype.clear()
	_worldLogger.debug("Cleared archetype storage after purge")

	# Purge all systems
	_worldLogger.debug("Purging All Systems")
	for group_key in systems_by_group.keys():
		for system in systems_by_group[group_key].duplicate():
			remove_system(system)

	# Purge all observers
	_worldLogger.debug("Purging Observers", observers)
	for observer in observers.duplicate():
		remove_observer(observer)

	_invalidate_cache("purge")

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

#region Signal Callbacks


## [signal Entity.component_added] Callback when a component is added to an entity.[br]
## [param entity] The entity that had a component added.[br]
## [param component] The resource path of the added component.
func _on_entity_component_added(entity: Entity, component: Resource) -> void:
	# ARCHETYPE: Move entity to new archetype
	if entity_to_archetype.has(entity):
		var old_archetype = entity_to_archetype[entity]
		var comp_path = component.get_script().resource_path
		var new_archetype = _move_entity_to_new_archetype_fast(
			entity, old_archetype, comp_path, true
		)
		# Must invalidate: QueryBuilder caches execute() results, not just archetype matches
		_invalidate_cache("entity_component_added")

	# Emit Signal
	component_added.emit(entity, component)
	_handle_observer_component_added(entity, component)
	if not entity.component_property_changed.is_connected(_on_entity_component_property_change):
		entity.component_property_changed.connect(_on_entity_component_property_change)
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_component_added(entity, component), "")


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
	# ARCHETYPE: No cache invalidation - property changes don't affect archetype membership
	# Send the message to the debugger if we're in debug
	if ECS.debug:
		assert(
			GECSEditorDebuggerMessages.entity_component_property_changed(
				entity, component, property_name, old_value, new_value
			),
			""
		)


## [signal Entity.component_removed] Callback when a component is removed from an entity.[br]
## [param entity] The entity that had a component removed.[br]
## [param component] The resource path of the removed component.
func _on_entity_component_removed(entity, component: Resource) -> void:
	if entity_to_archetype.has(entity):
		var old_archetype = entity_to_archetype[entity]
		var comp_path = component.resource_path
		var new_archetype = _move_entity_to_new_archetype_fast(
			entity, old_archetype, comp_path, false
		)
		# Must invalidate: QueryBuilder caches execute() results, not just archetype matches
		_invalidate_cache("entity_component_removed")

	component_removed.emit(entity, component)
	_handle_observer_component_removed(entity, component)
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_component_removed(entity, component), "")


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

	# PERFORMANCE: Do NOT invalidate archetype cache on relationship changes
	# Relationships do not alter archetype membership (structural component sets)
	# QueryBuilder.execute() performs relationship filtering on entity results.
	# Systems use archetypes() + per-entity filtering, so invalidation here only
	# increases cache churn without improving correctness.

	# Emit Signal
	relationship_added.emit(entity, relationship)
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_relationship_added(entity, relationship), "")


## (Optional) Update index when a relationship is removed.
func _on_entity_relationship_removed(entity: Entity, relationship: Relationship) -> void:
	var key = relationship.relation.resource_path
	if relationship_entity_index.has(key):
		relationship_entity_index[key].erase(entity)

	if is_instance_valid(relationship.target) and relationship.target is Entity:
		var rev_key = "reverse_" + key
		if reverse_relationship_index.has(rev_key):
			reverse_relationship_index[rev_key].erase(relationship.target)

	# PERFORMANCE: No cache invalidation (see comment in _on_entity_relationship_added)

	# Emit Signal
	relationship_removed.emit(entity, relationship)
	if ECS.debug:
		assert(GECSEditorDebuggerMessages.entity_relationship_removed(entity, relationship), "")


## Adds a single [Observer] to the [World].
## [param observer] The [Observer] to add.
## [b]Example:[/b]
##      [codeblock]world.add_observer(health_change_system)[/codeblock]
func add_observer(_observer: Observer) -> void:
	if not _observer.is_inside_tree():
		get_node(system_nodes_root).add_child(_observer)
	_worldLogger.trace("add_observer Adding Observer: ", _observer)
	observers.append(_observer)

	# Initialize the query builder for the observer
	_observer.q = QueryBuilder.new(self)

	# Verify the system has a valid watch component
	_observer.watch()  # Just call to validate it returns a component


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
			and component
			and component.get_script()
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
		if (
			watch_component
			and component
			and component.get_script()
			and watch_component.resource_path == component.get_script().resource_path
		):
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
			and component
			and component.get_script()
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


func _query(
	all_components = [],
	any_components = [],
	exclude_components = [],
	enabled_filter = null,
	precalculated_cache_key: int = -1
) -> Array:
	var _perf_start_total := 0
	if ECS.debug:
		_perf_start_total = Time.get_ticks_usec()
	# Early return if no components specified - return all entities
	if all_components.is_empty() and any_components.is_empty() and exclude_components.is_empty():
		if enabled_filter == null:
			if ECS.debug:
				perf_mark(
					"query_all_entities",
					Time.get_ticks_usec() - _perf_start_total,
					{"returned": entities.size()}
				)
			return entities
		else:
			# OPTIMIZATION: Use bitset filtering from all archetypes instead of entity.enabled check
			var filtered: Array[Entity] = []
			for archetype in archetypes.values():
				filtered.append_array(archetype.get_entities_by_enabled_state(enabled_filter))
			if ECS.debug:
				perf_mark(
					"query_all_entities_filtered",
					Time.get_ticks_usec() - _perf_start_total,
					{"returned": filtered.size(), "enabled_filter": enabled_filter}
				)
			return filtered

	# OPTIMIZATION: Use pre-calculated cache key if provided (avoids hash recalculation)
	var _perf_start_cache_key := 0
	if ECS.debug:
		_perf_start_cache_key = Time.get_ticks_usec()
	var cache_key = (
		precalculated_cache_key
		if precalculated_cache_key != -1
		else QueryCacheKey.build(all_components, any_components, exclude_components)
	)
	if ECS.debug:
		perf_mark("query_cache_key", Time.get_ticks_usec() - _perf_start_cache_key)

	# Check if we have cached matching archetypes for this query
	var matching_archetypes: Array[Archetype] = []
	if _query_archetype_cache.has(cache_key):
		_cache_hits += 1
		matching_archetypes = _query_archetype_cache[cache_key]
		if ECS.debug:
			perf_mark("query_cache_hit", 0, {"archetypes": matching_archetypes.size()})
	else:
		_cache_misses += 1
		var _perf_start_scan := 0
		if ECS.debug:
			_perf_start_scan = Time.get_ticks_usec()
		# Find all archetypes that match this query
		var map_resource_path = func(x): return x.resource_path
		var _all := all_components.map(map_resource_path)
		var _any := any_components.map(map_resource_path)
		var _exclude := exclude_components.map(map_resource_path)

		for archetype in archetypes.values():
			if archetype.matches_query(_all, _any, _exclude):
				matching_archetypes.append(archetype)
		# Cache the matching archetypes (not the entity arrays!)
		_query_archetype_cache[cache_key] = matching_archetypes
		if ECS.debug:
			perf_mark(
				"query_archetype_scan",
				Time.get_ticks_usec() - _perf_start_scan,
				{"archetypes": matching_archetypes.size()}
			)

	# OPTIMIZATION: If there's only ONE matching archetype with no filtering, return it directly
	# This avoids array allocation and copying for the common case
	if matching_archetypes.size() == 1 and enabled_filter == null:
		if ECS.debug:
			perf_mark(
				"query_single_archetype",
				Time.get_ticks_usec() - _perf_start_total,
				{"entities": matching_archetypes[0].entities.size()}
			)
		return matching_archetypes[0].entities

	# Collect entities from all matching archetypes with enabled filtering if needed
	var _perf_start_flatten := 0
	if ECS.debug:
		_perf_start_flatten = Time.get_ticks_usec()
	var result: Array[Entity] = []
	for archetype in matching_archetypes:
		if enabled_filter == null:
			# No filtering - add all entities
			result.append_array(archetype.entities)
		else:
			# OPTIMIZATION: Use bitset filtering instead of per-entity enabled check
			result.append_array(archetype.get_entities_by_enabled_state(enabled_filter))
	if ECS.debug:
		perf_mark(
			"query_flatten",
			Time.get_ticks_usec() - _perf_start_flatten,
			{"returned": result.size(), "archetypes": matching_archetypes.size()}
		)
		perf_mark(
			"query_total", Time.get_ticks_usec() - _perf_start_total, {"returned": result.size()}
		)

	return result


## OPTIMIZATION: Group entities by their archetype for column-based iteration
## Enables systems to use get_column() for cache-friendly array access
## [param entities] Array of entities to group
## [returns] Dictionary mapping Archetype -> Array[Entity]
##
## Example usage in a System:
## [codeblock]
## func process_all(entities: Array, delta: float):
##     var grouped = ECS.world.group_entities_by_archetype(entities)
##     for archetype in grouped.keys():
##         process_columns(archetype, delta)
## [/codeblock]
func group_entities_by_archetype(entities: Array) -> Dictionary:
	var grouped = {}
	for entity in entities:
		if entity_to_archetype.has(entity):
			var archetype = entity_to_archetype[entity]
			if not grouped.has(archetype):
				grouped[archetype] = []
			grouped[archetype].append(entity)
	return grouped


## OPTIMIZATION: Get matching archetypes directly from query (no entity array flattening)
## This is MUCH faster than query().execute() + group_entities_by_archetype()
## [param query_builder] The query to execute
## [returns] Array of matching archetypes
##
## Example usage in a System:
## [codeblock]
## func process_all(entities: Array, delta: float):
##     # OLD WAY (slow):
##     # var grouped = ECS.world.group_entities_by_archetype(entities)
##
##     # NEW WAY (fast):
##     var archetypes = ECS.world.get_matching_archetypes(q.with_all([C_Velocity]))
##     for archetype in archetypes:
##         var velocities = archetype.get_column(C_Velocity.resource_path)
##         for i in range(velocities.size()):
##             # Process with cache-friendly column access
## [/codeblock]
func get_matching_archetypes(query_builder: QueryBuilder) -> Array[Archetype]:
	var _perf_start := 0
	if ECS.debug:
		_perf_start = Time.get_ticks_usec()
	# PERFORMANCE: Archetype matching is based ONLY on structural components.
	# Relationship/group filters are evaluated per-entity in System execution.
	# This avoids double-scanning entities (World + System) and reduces cache churn.
	var all_components = query_builder._all_components
	var any_components = query_builder._any_components
	var exclude_components = query_builder._exclude_components

	# Use a COMPONENT-ONLY cache key (ignore relationships/groups)
	var cache_key = QueryCacheKey.build(all_components, any_components, exclude_components)

	if _query_archetype_cache.has(cache_key):
		if ECS.debug:
			perf_mark("archetypes_cache_hit", Time.get_ticks_usec() - _perf_start)
		return _query_archetype_cache[cache_key]

	var map_resource_path = func(x): return x.resource_path
	var _all := all_components.map(map_resource_path)
	var _any := any_components.map(map_resource_path)
	var _exclude := exclude_components.map(map_resource_path)

	var matching: Array[Archetype] = []
	var _perf_scan_start := 0
	if ECS.debug:
		_perf_scan_start = Time.get_ticks_usec()
	for archetype in archetypes.values():
		if archetype.matches_query(_all, _any, _exclude):
			matching.append(archetype)
	if ECS.debug:
		perf_mark(
			"archetypes_scan",
			Time.get_ticks_usec() - _perf_scan_start,
			{"archetypes": matching.size()}
		)

	_query_archetype_cache[cache_key] = matching
	if ECS.debug:
		perf_mark(
			"archetypes_total", Time.get_ticks_usec() - _perf_start, {"archetypes": matching.size()}
		)
	return matching


## Get performance statistics for cache usage
func get_cache_stats() -> Dictionary:
	var total_requests = _cache_hits + _cache_misses
	var hit_rate = 0.0 if total_requests == 0 else float(_cache_hits) / float(total_requests)
	return {
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"hit_rate": hit_rate,
		"cached_queries": _query_archetype_cache.size(),
		"total_archetypes": archetypes.size(),
		"invalidation_count": _cache_invalidation_count,
		"invalidation_reasons": _cache_invalidation_reasons.duplicate()
	}


## Reset cache statistics
func reset_cache_stats() -> void:
	_cache_hits = 0
	_cache_misses = 0
	_cache_invalidation_count = 0
	_cache_invalidation_reasons.clear()


## Internal helper to track cache invalidations (debug mode only)
func _invalidate_cache(reason: String) -> void:
	# OPTIMIZATION: Skip invalidation during batch operations
	if not _should_invalidate_cache:
		return

	_query_archetype_cache.clear()
	cache_invalidated.emit()

	# Track invalidation stats (debug mode only)
	if ECS.debug:
		_cache_invalidation_count += 1
		_cache_invalidation_reasons[reason] = _cache_invalidation_reasons.get(reason, 0) + 1


## Calculate archetype signature for an entity based on its components
## Uses the same hash function as queries for consistency
## An entity signature is just a query with all its components (no any/exclude)
func _calculate_entity_signature(entity: Entity) -> int:
	# Get component resource paths
	var comp_paths = entity.components.keys()
	comp_paths.sort()  # Sort paths for consistent ordering

	# Convert paths to Script objects using cached scripts (load once, reuse forever)
	var comp_scripts = []
	for comp_path in comp_paths:
		# Check cache first
		if not _component_script_cache.has(comp_path):
			# Load once and cache
			var component = entity.components[comp_path]
			_component_script_cache[comp_path] = component.get_script()
		comp_scripts.append(_component_script_cache[comp_path])

	# Use the SAME hash function as queries - entity is just "all components, no any/exclude"
	# OPTIMIZATION: Removed enabled_marker from signature - now handled by bitset in archetype
	var signature = QueryCacheKey.build(comp_scripts, [], [])

	return signature


## Get or create an archetype for the given signature and component types
func _get_or_create_archetype(signature: int, component_types: Array) -> Archetype:
	var is_new = not archetypes.has(signature)
	if is_new:
		var archetype = Archetype.new(signature, component_types)
		archetypes[signature] = archetype
		_worldLogger.trace("Created new archetype: ", archetype)

		# ARCHETYPE OPTIMIZATION: Only invalidate cache when NEW archetype is created
		# This is rare compared to entities moving between existing archetypes
		_invalidate_cache("new_archetype_created")

	return archetypes[signature]


## Add entity to appropriate archetype (parallel system)
func _add_entity_to_archetype(entity: Entity) -> void:
	# Calculate signature based on entity's components (enabled state now handled by bitset)
	var signature = _calculate_entity_signature(entity)

	# Get component type paths for this entity
	var comp_types = entity.components.keys()

	# Get or create archetype (no longer needs enabled filter value)
	var archetype = _get_or_create_archetype(signature, comp_types)

	# Add entity to archetype
	archetype.add_entity(entity)
	entity_to_archetype[entity] = archetype

	# Must invalidate: QueryBuilder caches execute() results
	_invalidate_cache("entity_added_to_archetype")

	_worldLogger.trace("Added entity ", entity.name, " to archetype: ", archetype)


## Remove entity from its current archetype
func _remove_entity_from_archetype(entity: Entity) -> bool:
	if not entity_to_archetype.has(entity):
		return false

	var archetype = entity_to_archetype[entity]
	var removed = archetype.remove_entity(entity)
	entity_to_archetype.erase(entity)

	# Must invalidate: QueryBuilder caches execute() results
	_invalidate_cache("entity_removed_from_archetype")

	# Clean up empty archetypes (optional - can keep them for reuse)
	if archetype.is_empty():
		# Break circular references before removing
		archetype.add_edges.clear()
		archetype.remove_edges.clear()
		archetypes.erase(archetype.signature)
		_worldLogger.trace("Removed empty archetype: ", archetype)
		# OPTIMIZATION: Only invalidate when archetype is actually removed from world
		_invalidate_cache("empty_archetype_removed")

	return removed


## Fast path: Move entity when we already know which component was added/removed
## This avoids expensive set comparisons to find the difference
## Returns the new archetype the entity was moved to
func _move_entity_to_new_archetype_fast(
	entity: Entity, old_archetype: Archetype, comp_path: String, is_add: bool
) -> Archetype:
	# Try to use archetype edge for O(1) transition
	var new_archetype: Archetype = null

	if is_add:
		# Check if we have a cached edge for this component addition
		new_archetype = old_archetype.get_add_edge(comp_path)
	else:
		# Check if we have a cached edge for this component removal
		new_archetype = old_archetype.get_remove_edge(comp_path)

	# BUG FIX: If archetype retrieved from edge cache was removed from world.archetypes
	# when it became empty, re-add it so queries can find it
	if new_archetype != null and not archetypes.has(new_archetype.signature):
		archetypes[new_archetype.signature] = new_archetype
		_worldLogger.trace("Re-added archetype from edge cache: ", new_archetype)

	# If no cached edge, calculate signature and find/create archetype
	if new_archetype == null:
		var new_signature = _calculate_entity_signature(entity)
		var comp_types = entity.components.keys()
		new_archetype = _get_or_create_archetype(new_signature, comp_types)

		# Cache the edge for next time (archetype graph optimization)
		if is_add:
			old_archetype.set_add_edge(comp_path, new_archetype)
			new_archetype.set_remove_edge(comp_path, old_archetype)
		else:
			old_archetype.set_remove_edge(comp_path, new_archetype)
			new_archetype.set_add_edge(comp_path, old_archetype)

	# Remove from old archetype
	old_archetype.remove_entity(entity)

	# Add to new archetype
	new_archetype.add_entity(entity)
	entity_to_archetype[entity] = new_archetype

	_worldLogger.trace("Moved entity ", entity.name, " from ", old_archetype, " to ", new_archetype)

	# Clean up empty old archetype
	if old_archetype.is_empty():
		# Break circular references before removing
		old_archetype.add_edges.clear()
		old_archetype.remove_edges.clear()
		archetypes.erase(old_archetype.signature)

	return new_archetype


## Move entity from one archetype to another (when components change)
## Uses archetype edges for O(1) transitions when possible
## NOTE: This slow path compares sets - only used when we don't know which component changed
func _move_entity_to_new_archetype(entity: Entity, old_archetype: Archetype) -> void:
	# Determine which component was added/removed by comparing old archetype with current entity
	var old_comp_set = {}
	for comp_path in old_archetype.component_types:
		old_comp_set[comp_path] = true

	var new_comp_set = {}
	for comp_path in entity.components.keys():
		new_comp_set[comp_path] = true

	# Find the difference (added or removed component)
	var added_comp: String = ""
	var removed_comp: String = ""

	for comp_path in new_comp_set.keys():
		if not old_comp_set.has(comp_path):
			added_comp = comp_path
			break

	for comp_path in old_comp_set.keys():
		if not new_comp_set.has(comp_path):
			removed_comp = comp_path
			break

	# Try to use archetype edge for O(1) transition
	var new_archetype: Archetype = null

	if added_comp != "":
		# Check if we have a cached edge for this component addition
		new_archetype = old_archetype.get_add_edge(added_comp)
	elif removed_comp != "":
		# Check if we have a cached edge for this component removal
		new_archetype = old_archetype.get_remove_edge(removed_comp)

	# If no cached edge, calculate signature and find/create archetype
	if new_archetype == null:
		var new_signature = _calculate_entity_signature(entity)
		var comp_types = entity.components.keys()
		new_archetype = _get_or_create_archetype(new_signature, comp_types)

		# Cache the edge for next time (archetype graph optimization)
		if added_comp != "":
			old_archetype.set_add_edge(added_comp, new_archetype)
			new_archetype.set_remove_edge(added_comp, old_archetype)
		elif removed_comp != "":
			old_archetype.set_remove_edge(removed_comp, new_archetype)
			new_archetype.set_add_edge(removed_comp, old_archetype)

	# Remove from old archetype
	old_archetype.remove_entity(entity)

	# Add to new archetype
	new_archetype.add_entity(entity)
	entity_to_archetype[entity] = new_archetype

	_worldLogger.trace("Moved entity ", entity.name, " from ", old_archetype, " to ", new_archetype)

	# Clean up empty old archetype
	if old_archetype.is_empty():
		# Break circular references before removing
		old_archetype.add_edges.clear()
		old_archetype.remove_edges.clear()
		archetypes.erase(old_archetype.signature)


#endregion Utility Methods

#region Debugger Support


## Handle messages from the editor debugger
func _handle_debugger_message(message: String, data: Array) -> bool:
	if message == "set_system_active":
		# Editor requested to toggle a system's active state
		var system_id = data[0]
		var new_active = data[1]

		# Find the system by instance ID
		for sys in systems:
			if sys.get_instance_id() == system_id:
				sys.active = new_active

				# Send confirmation back to editor
				GECSEditorDebuggerMessages.system_added(sys)
				return true

		return false
	elif message == "poll_entity":
		# Editor requested a component poll for a specific entity
		var entity_id = data[0]
		_poll_entity_for_debugger(entity_id)
		return true
	elif message == "select_entity":
		# Editor requested to select an entity in the scene tree
		var entity_path = data[0]
		print("GECS World: Received select_entity request for path: ", entity_path)
		# Get the actual node to get its ObjectID
		var node = get_node_or_null(entity_path)
		if node:
			var obj_id = node.get_instance_id()
			var _class_name = node.get_class()
			# The path needs to be an array of node names from root to target
			var path_array = str(entity_path).split("/", false)
			print("  Found node, sending inspect message")
			print("    ObjectID: ", obj_id)
			print("    Class: ", _class_name)

			if GECSEditorDebuggerMessages.can_send_message():
				# The scene:inspect_object format per Godot source code:
				# [object_id (uint64), class_name (STRING), properties_array (ARRAY)]
				# NO path_array! Just 3 elements total
				# properties_array contains arrays of 6 elements each:
				# [name (STRING), type (INT), hint (INT), hint_string (STRING), usage (INT), value (VARIANT)]
				# Get actual properties from the node
				var properties: Array = []
				var prop_list = node.get_property_list()
				# Add properties (limit to avoid huge payload)
				for i in range(min(20, prop_list.size())):
					var prop = prop_list[i]
					var prop_name: String = prop.name
					var prop_type: int = prop.type
					var prop_hint: int = prop.get("hint", 0)
					var prop_hint_string: String = prop.get("hint_string", "")
					var prop_usage: int = prop.usage
					var prop_value = node.get(prop_name)

					var prop_info: Array = [
						prop_name, prop_type, prop_hint, prop_hint_string, prop_usage, prop_value
					]
					properties.append(prop_info)

				# Message format: [object_id, class_name, properties] - only 3 elements!
				var msg_data: Array = [obj_id, _class_name, properties]
				print(
					"    Sending scene:inspect_object: [",
					obj_id,
					", ",
					_class_name,
					", ",
					properties.size(),
					" props]"
				)
				EngineDebugger.send_message("scene:inspect_object", msg_data)
		else:
			print("  ERROR: Could not find node at path: ", entity_path)
		return true
	return false


## Poll a specific entity's components and send updates to the debugger
func _poll_entity_for_debugger(entity_id: int) -> void:
	# Find the entity by instance ID
	var entity: Entity = null
	for ent in entities:
		if ent.get_instance_id() == entity_id:
			entity = ent
			break

	if entity == null:
		return

	# Re-send all component data with fresh serialize() calls
	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		if comp and comp is Resource:
			# Send updated component data
			GECSEditorDebuggerMessages.entity_component_added(entity, comp)

#endregion Debugger Support
