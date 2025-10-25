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
var systemLogger := GECSLogger.new().domain("System")
## Data for debugger and profiling
var lastRunData := {}

## Reference to the world this system belongs to (set by World.add_system)
var _world: World = null
## Convenience property for accessing query builder (returns _world.query or ECS.world.query)
var q: QueryBuilder:
	get:
		return _world.query if _world else ECS.world.query
## Cached query to avoid recreating it every frame (lazily initialized)
var _query_cache: QueryBuilder = null
## Cached subsystems to avoid recreating them every frame (lazily initialized)
var _subsystems_cache: Array[Array] = []
## Cached component resource paths from iterate() for batch mode (lazily initialized)
var _component_paths: Array[String] = []

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
func process(entities: Array[Entity], components: Array[Array], delta: float) -> void:
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
func _process_parallel(entities: Array[Entity], components: Array[Array], delta: float) -> void:
	if entities.is_empty():
		return

	# Use OS thread count as fallback since WorkerThreadPool.get_thread_count() doesn't exist
	var worker_count := OS.get_processor_count()
	var batch_size := maxi(1, entities.size() / worker_count)
	var tasks: Array[int] = []

	# Submit tasks for each batch
	for batch_start in range(0, entities.size(), batch_size):
		var batch_end := mini(batch_start + batch_size, entities.size())

		# Slice entities and components for this batch
		var batch_entities := entities.slice(batch_start, batch_end) as Array[Entity]
		var batch_components: Array[Array] = []
		for comp_array in components:
			batch_components.append(comp_array.slice(batch_start, batch_end) as Array[Component])

		var task_id := WorkerThreadPool.add_task(_process_batch_callable.bind(batch_entities, batch_components, delta))
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
	var subs := sub_systems()
	if not subs.is_empty():
		_run_subsystems(delta)
	else:
		_run_process(delta)

	# DEBUG: Record execution time (compiled out in production, disabled via ECS.debug in perf tests)
	if ECS.debug:
		var end_time_usec := Time.get_ticks_usec()
		var execution_time_ms := (end_time_usec - start_time_usec) / 1000.0
		lastRunData["execution_time_ms"] = execution_time_ms


## Execution path for subsystems
func _run_subsystems(delta: float) -> void:
	# Lazy initialize subsystems cache
	if _subsystems_cache.is_empty():
		_subsystems_cache = sub_systems()

	# Execute each subsystem
	var subsystem_index := 0
	for subsystem_tuple in _subsystems_cache:
		var subsystem_query := subsystem_tuple[0] as QueryBuilder
		var subsystem_callable := subsystem_tuple[1] as Callable

		# Get matching archetypes and process them
		var matching_archetypes := subsystem_query.archetypes()
		var iterate_comps := subsystem_query._iterate_components
		var total_entity_count := 0

		# Process each archetype separately for cache locality
		for archetype in matching_archetypes:
			if archetype.entities.is_empty():
				continue

			total_entity_count += archetype.entities.size()

			var components: Array[Array] = []
			# Gather component columns if iterate() was called
			if not iterate_comps.is_empty():
				for comp_type in iterate_comps:
					var comp_path: String = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
					components.append(archetype.get_column(comp_path))

			# Call with archetype data
			subsystem_callable.call(archetype.entities, components, delta)

		if ECS.debug:
			lastRunData[subsystem_index] = {
				"subsystem_index": subsystem_index,
				"entity_count": total_entity_count
			}
		subsystem_index += 1


## Unified execution path for main system query
func _run_process(delta: float) -> void:
	# Lazy initialize query cache
	if not _query_cache:
		_query_cache = query()

	# Lazy initialize component paths from iterate()
	if _component_paths.is_empty():
		var iterate_comps := _query_cache._iterate_components
		# Cache component resource paths in iteration order (if iterate() was called)
		for comp_type in iterate_comps:
			var comp_path: String = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
			_component_paths.append(comp_path)

	# Get matching archetypes directly (zero-copy, cache-friendly)
	var matching_archetypes := _query_cache.archetypes()
	var iterate_comps := _query_cache._iterate_components
	var has_entities := false
	var total_entity_count := 0

	# Check if we have any entities at all
	for arch in matching_archetypes:
		if not arch.entities.is_empty():
			has_entities = true
			total_entity_count += arch.entities.size()

	# DEBUG: Track entity count (compiled out in production)
	if ECS.debug:
		lastRunData["entity_count"] = total_entity_count
		lastRunData["archetype_count"] = matching_archetypes.size()

	# If no entities and we don't process when empty, exit early
	if not has_entities and not process_empty:
		return

	# If no entities but process_empty is true, call once with empty data
	if not has_entities and process_empty:
		process([], [], delta)
		return

	# Iterate each archetype separately for cache locality
	for arch in matching_archetypes:
		var arch_entities := arch.entities

		# Skip empty archetypes (we only call with actual entities)
		if arch_entities.is_empty():
			continue

		var components: Array[Array] = []

		# Gather component columns if iterate() was called
		if not iterate_comps.is_empty():
			for comp_path in _component_paths:
				components.append(arch.get_column(comp_path))

		# Use parallel processing if enabled and we have enough entities
		if parallel_processing and arch_entities.size() >= parallel_threshold:
			if ECS.debug:
				lastRunData["parallel"] = true
				lastRunData["threshold"] = parallel_threshold
			_process_parallel(arch_entities, components, delta)
		else:
			# Call user's process() callback with this archetype's data
			if ECS.debug:
				lastRunData["parallel"] = false
			process(arch_entities, components, delta)


## Debug helper - updates lastRunData (compiled out in production)
func _update_debug_data(callable: Callable = func(): return {}) -> bool:
	if ECS.debug:
		var data := callable.call()
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
