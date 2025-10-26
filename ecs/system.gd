## System[br]
##
## The base class for all systems within the ECS framework.[br]
##
## Systems contain the core logic and behavior, processing [Entity]s that have specific [Component]s.[br]
## Each system overrides the [method System.query] and returns a query using [code]q[/code] or [code]ECS.world.query[/code][br]
## to define the required [Component]s for it to process [Entity]s and implements the [method System.process] method.[br][br]
## [b]Example (Simple):[/b]
##[codeblock]
##     class_name MovementSystem
##     extends System
##
##     func query():
##         return q.with_all([Transform, Velocity])
##
##     func process(entities: Array[Entity], components: Array, delta: float) -> void:
##         # Per-entity processing (simple but slower)
##         for entity in entities:
##             var transform = entity.get_component(Transform)
##             var velocity = entity.get_component(Velocity)
##             transform.position += velocity.direction * velocity.speed * delta
##[/codeblock]
## [b]Example (Optimized with iterate()):[/b]
##[codeblock]
##     func query():
##         return q.with_all([Transform, Velocity]).iterate([Transform, Velocity])
##
##     func process(entities: Array[Entity], components: Array, delta: float) -> void:
##         # Batch processing with component arrays (faster)
##         var transforms = components[0]
##         var velocities = components[1]
##         for i in entities.size():
##             transforms[i].position += velocities[i].velocity * delta
##[/codeblock]
@icon("res://addons/gecs/assets/system.svg")
class_name System
extends Node

#region Enums
## These control when the system should run in relation to other systems.
enum Runs {
	## This system should run before all the systems defined in the array ex: [TransformSystem] means it will run before the [TransformSystem] system runs
	Before,
	## This system should run after all the systems defined in the array ex: [TransformSystem] means it will run after the [TransformSystem] system runs
	After,
}

#endregion Enums

#region Exported Variables
## What group this system belongs to. Systems can be organized and run by group
@export var group: String = ""
## Determines whether the system should run even when there are no [Entity]s to process.
@export var process_empty := false
## Is this system active. (Will be skipped if false)
@export var active := true

@export_group("Parallel Processing")
## Enable parallel processing for this system's entities (No access to scene tree in process method)
@export var parallel_processing := false
## Minimum entities required to use parallel processing (performance threshold)
@export var parallel_threshold := 50

#endregion Exported Variables

#region Public Variables
## Is this system paused. (Will be skipped if true)
var paused := false

## Logger for system debugging and tracing
var systemLogger = GECSLogger.new().domain("System")
## Data for debugger and profiling - you can add ANY arbitrary data here when ECS.debug is enabled
## All keys and values will automatically appear in the GECS debugger tab
## Example:
##   if ECS.debug:
##       lastRunData["my_counter"] = 123
##       lastRunData["player_stats"] = {"health": 100, "mana": 50}
##       lastRunData["events"] = ["event1", "event2"]
var lastRunData := {}

## Reference to the world this system belongs to (set by World.add_system)
var _world: World = null
## Convenience property for accessing query builder (returns _world.query or ECS.world.query)
var q: QueryBuilder:
	get:
		return _world.query if _world else ECS.world.query
## Cached query to avoid recreating it every frame (lazily initialized)
var _query_cache: QueryBuilder = null

#endregion Public Variables

#region Public Methods
## Override this method to define the [System]s that this system depends on.[br]
## If not overridden the system will run based on the order of the systems in the [World][br]
## and the order of the systems in the [World] will be based on the order they were added to the [World].[br]
func deps() -> Dictionary[int, Array]:
	return {
		Runs.After: [],
		Runs.Before: [],
	}


## Override this method and return a [QueryBuilder] to define the required [Component]s for the system.[br]
## If not overridden, the system will run on every update with no entities.[br][br]
## You can use [code]q[/code] or [code]ECS.world.query[/code] - both are equivalent.
func query() -> QueryBuilder:
	process_empty = true
	return _world.query if _world else ECS.world.query


## Override this method to define any sub-systems that should be processed by this system.[br]
## Each subsystem is defined as [QueryBuilder, Callable][br]
## Return empty array if not using subsystems (base implementation)[br][br]
## You can use [code]q[/code] or [code]ECS.world.query[/code] in subsystems - both work.[br][br]
## [b]Example:[/b]
## [codeblock]
## func sub_systems() -> Array[Array]:
##     return [
##         [q.with_all([C_Velocity]).iterate([C_Velocity]), process_velocity],
##         [q.with_all([C_Health]), process_health]
##     ]
##
## func process_velocity(entities: Array[Entity], components: Array, delta: float):
##     var velocities = components[0]
##     for i in entities.size():
##         entities[i].position += velocities[i].velocity * delta
##
## func process_health(entities: Array[Entity], components: Array, delta: float):
##     for entity in entities:
##         var health = entity.get_component(C_Health)
##         health.regenerate(delta)
## [/codeblock]
func sub_systems() -> Array[Array]:
	return [] # Base returns empty - overridden systems return populated Array[Array]


## Runs once after the system has been added to the [World] to setup anything on the system one time[br]
func setup():
	pass # Override in subclasses if needed


## The main processing function for the system.[br]
## Override this method to define your system's behavior.[br]
## [param entities] Array of entities matching the system's query[br]
## [param components] Array of component arrays (in order from iterate()), or empty if no iterate() call[br]
## [param delta] The time elapsed since the last frame[br][br]
## [b]Simple approach:[/b] Loop through entities and use get_component()[br]
## [b]Fast approach:[/b] Use iterate() in query and access component arrays directly
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	pass # Override in subclasses - base implementation does nothing

#endregion Public Methods

#region Private Methods


## INTERNAL: Called by World.add_system() to initialize the system
## DO NOT CALL OR OVERRIDE - this is framework code
func _internal_setup():
	# Call user setup
	setup()

## Process entities in parallel using WorkerThreadPool
## Splits entities into batches and processes them concurrently
func _process_parallel(entities: Array[Entity], components: Array, delta: float) -> void:
	if entities.is_empty():
		return

	# Use OS thread count as fallback since WorkerThreadPool.get_thread_count() doesn't exist
	var worker_count = OS.get_processor_count()
	var batch_size = max(1, entities.size() / worker_count)
	var tasks = []

	# Submit tasks for each batch
	for batch_start in range(0, entities.size(), batch_size):
		var batch_end = min(batch_start + batch_size, entities.size())

		# Slice entities and components for this batch
		var batch_entities = entities.slice(batch_start, batch_end)
		var batch_components = []
		for comp_array in components:
			batch_components.append(comp_array.slice(batch_start, batch_end))

		var task_id = WorkerThreadPool.add_task(_process_batch_callable.bind(batch_entities, batch_components, delta))
		tasks.append(task_id)

	# Wait for all tasks to complete
	for task_id in tasks:
		WorkerThreadPool.wait_for_task_completion(task_id)


## Process a batch of entities - called by worker threads
func _process_batch_callable(entities: Array[Entity], components: Array, delta: float) -> void:
	process(entities, components, delta)


## Called by World.process() each frame - main entry point for system execution
## [param delta] The time elapsed since the last frame
func _handle(delta: float) -> void:
	# Early exit: system is disabled or paused
	if not active or paused:
		return

	# DEBUG: Track execution time (compiled out in production, disabled via ECS.debug in perf tests)
	var start_time_usec := 0
	if ECS.debug:
		start_time_usec = Time.get_ticks_usec()
		lastRunData = {
			"system_name": get_script().resource_path.get_file().get_basename(),
			"frame_delta": delta,
		}

	# Check if using subsystems or main query
	var subs = sub_systems()
	if not subs.is_empty():
		# Subsystems are PURE syntactic sugar - they work EXACTLY like regular systems
		# Each subsystem processes per-archetype, just like a regular system would
		var subsystem_index := 0
		for subsystem_tuple in subs:
			var subsystem_query := subsystem_tuple[0] as QueryBuilder
			var subsystem_callable := subsystem_tuple[1] as Callable

			# Execute this subsystem EXACTLY like a regular system
			_execute_system_query(subsystem_query, subsystem_callable, delta, subsystem_index)

			subsystem_index += 1
	else:
		# Lazy initialize query cache for main system
		if not _query_cache:
			_query_cache = query()

		# Execute main system - identical execution to subsystems
		_execute_system_query(_query_cache, process, delta, -1)

	# DEBUG: Record execution time (compiled out in production, disabled via ECS.debug in perf tests)
	if ECS.debug:
		var end_time_usec = Time.get_ticks_usec()
		var execution_time_ms = (end_time_usec - start_time_usec) / 1000.0
		lastRunData["execution_time_ms"] = execution_time_ms


## UNIFIED execution function for both main systems and subsystems
## This ensures consistent behavior and entity processing logic
## Subsystems and main systems execute IDENTICALLY - no special behavior
## [param query_builder] The query to execute
## [param callable] The function to call with matched entities
## [param delta] Time delta
## [param subsystem_index] Index for debug tracking (-1 for main system)
func _execute_system_query(query_builder: QueryBuilder, callable: Callable, delta: float, subsystem_index: int) -> void:
	# Lazy initialize component paths from iterate() for this query
	var component_paths: Array[String] = []
	var iterate_comps = query_builder._iterate_components

	# Cache component resource paths in iteration order (if iterate() was called)
	if not iterate_comps.is_empty():
		for comp_type in iterate_comps:
			var comp_path = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
			component_paths.append(comp_path)

	# IMPORTANT: Query archetypes FRESH each time to see changes from previous subsystems
	# Cache invalidation (in world.gd) ensures we see current archetype state after component changes
	var matching_archetypes = query_builder.archetypes()
	var has_entities = false
	var total_entity_count := 0

	# Check if we have any entities at all
	for arch in matching_archetypes:
		if not arch.entities.is_empty():
			has_entities = true
			total_entity_count += arch.entities.size()

	# DEBUG: Track entity count (compiled out in production)
	if ECS.debug:
		if subsystem_index >= 0:
			# Subsystem tracking
			lastRunData[subsystem_index] = {
				"subsystem_index": subsystem_index,
				"entity_count": total_entity_count,
				"archetype_count": matching_archetypes.size()
			}
		else:
			# Main system tracking
			lastRunData["entity_count"] = total_entity_count
			lastRunData["archetype_count"] = matching_archetypes.size()

	# If no entities and we don't process when empty, exit early
	if not has_entities and not process_empty:
		return

	# If no entities but process_empty is true, call once with empty data
	if not has_entities and process_empty:
		callable.call([], [], delta)
		return

	# IMPORTANT: Snapshot entities before processing to prevent double-processing
	# If we process per-archetype and entities move archetypes during processing,
	# they could be processed twice. By taking a snapshot of entity IDs first,
	# we ensure each entity is processed exactly once even if it changes archetypes.
	var processed_entity_ids: Dictionary = {}  # entity_id -> true

	# Get relationship and group filters from query
	var relationships = query_builder._relationships
	var exclude_relationships = query_builder._exclude_relationships
	var groups = query_builder._groups
	var exclude_groups = query_builder._exclude_groups
	var has_relationship_filters = not relationships.is_empty() or not exclude_relationships.is_empty()
	var has_group_filters = not groups.is_empty() or not exclude_groups.is_empty()

	# Iterate each archetype separately for cache locality
	for arch in matching_archetypes:
		var arch_entities = arch.entities.duplicate()  # Snapshot to prevent modification during iteration

		# Skip empty archetypes (we only call with actual entities)
		if arch_entities.is_empty():
			continue

		# Filter entities by relationship/group criteria if needed
		# NOTE: get_matching_archetypes() already filters archetypes to only those with matching entities,
		# but we still need to filter individual entities within each archetype
		if has_relationship_filters or has_group_filters:
			var filtered_entities: Array[Entity] = []

			for entity in arch_entities:
				var matches = true

				# Check relationships
				if has_relationship_filters and matches:
					for relationship in relationships:
						if not entity.has_relationship(relationship):
							matches = false
							break
					if matches:
						for ex_relationship in exclude_relationships:
							if entity.has_relationship(ex_relationship):
								matches = false
								break

				# Check groups
				if has_group_filters and matches:
					for group_name in groups:
						if not entity.is_in_group(group_name):
							matches = false
							break
					if matches:
						for exclude_group_name in exclude_groups:
							if entity.is_in_group(exclude_group_name):
								matches = false
								break

				if matches:
					filtered_entities.append(entity)

			arch_entities = filtered_entities

		# Filter out already-processed entities (prevents double-processing when archetypes change)
		var unprocessed_entities: Array[Entity] = []
		for entity in arch_entities:
			var entity_id = entity.get_instance_id()
			if not processed_entity_ids.has(entity_id):
				unprocessed_entities.append(entity)
				processed_entity_ids[entity_id] = true

		# Skip if all entities in this archetype were already processed
		if unprocessed_entities.is_empty():
			continue

		var components = []

		# Gather component columns if iterate() was called
		# NOTE: We need to rebuild component arrays for only the unprocessed entities
		if not iterate_comps.is_empty():
			for comp_path in component_paths:
				var comp_array = []
				for entity in unprocessed_entities:
					comp_array.append(entity.components[comp_path])
				components.append(comp_array)

		# Use parallel processing if enabled and we have enough entities
		# NOTE: Only main system (subsystem_index == -1) uses parallel processing setting
		if subsystem_index == -1 and parallel_processing and unprocessed_entities.size() >= parallel_threshold:
			if ECS.debug:
				lastRunData["parallel"] = true
				lastRunData["threshold"] = parallel_threshold
			_process_parallel(unprocessed_entities, components, delta)
		else:
			# Call the callable with this archetype's data
			if ECS.debug and subsystem_index == -1:
				lastRunData["parallel"] = false
			callable.call(unprocessed_entities, components, delta)


## Debug helper - updates lastRunData (compiled out in production)
func _update_debug_data(callable: Callable = func(): return {}) -> bool:
	if ECS.debug:
		var data = callable.call()
		if data:
			lastRunData.assign(data)
	return true


## Debug helper - sets lastRunData (compiled out in production)
func _debug_data(_lrd: Dictionary, callable: Callable = func(): return {}) -> bool:
	if ECS.debug:
		lastRunData = _lrd
		lastRunData.assign(callable.call())
	return true

#endregion Private Methods
