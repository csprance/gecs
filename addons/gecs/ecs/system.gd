## System[br]
##
## The base class for all systems within the ECS framework.[br]
##
## Systems contain the core logic and behavior, processing [Entity]s that have specific [Component]s.[br]
## Each system overrides the [method System.query] and returns a query using [code]q[/code] or [code]ECS.world.query[/code][br]
## to define the required [Component]s for it to process an [Entity] and implements the [method System.process] method.[br][br]
## [b]Example:[/b]
##[codeblock]
##     class_name MovementSystem
##     extends System
##
##     func query():
##         return q.with_all([Transform, Velocity])
##
##     func process(entity: Entity, delta: float) -> void:
##         var transform = entity.get_component(Transform)
##         var velocity = entity.get_component(Velocity)
##         transform.position += velocity.direction * velocity.speed * delta
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

## Execution methods for systems
enum ExecutionMethod {
	## Default per-entity processing using process()
	PROCESS = 0,
	## Bulk processing using process_all()
	PROCESS_ALL = 1,
	## Cache-friendly batch processing using process_batch()
	PROCESS_BATCH = 2,
	## Custom subsystem logic using sub_systems()
	SUBSYSTEMS = 3,
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
var _subsystems_cache: Array = []
## Cached component resource paths from iterate() for batch mode (lazily initialized)
var _batch_component_paths: Array[String] = []
## Cached execution method determined once at setup
var _execution_method: ExecutionMethod = ExecutionMethod.PROCESS

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
## Each subsystem is defined as [QueryBuilder, Callable, ExecutionMethod][br]
## Return empty array if not using subsystems (base implementation)[br][br]
## You can use [code]q[/code] or [code]ECS.world.query[/code] in subsystems - both work.[br][br]
## [b]Example:[/b]
## [codeblock]
## func sub_systems() -> Array[Array]:
##     return [
##         [q.with_all([C_Velocity]).iterate([C_Velocity]), process_velocity, ExecutionMethod.PROCESS_BATCH],
##         [q.with_all([C_Health]), process_health, ExecutionMethod.PROCESS]
##     ]
## [/codeblock]
func sub_systems() -> Array[Array]:
	return [] # Base returns empty - overridden systems return populated Array[Array]


## Override this method to use optimized batch processing with Structure-of-Arrays (SoA).[br]
## Receives entities and component arrays in batches for cache-friendly processing.[br]
## Components are provided in the same order as defined in query.iterate()[br][br]
## [b]Example:[/b]
## [codeblock]
## func query() -> QueryBuilder:
##     return q.with_all([C_Velocity, C_Transform]).iterate([C_Velocity, C_Transform])
##
## func process_batch(entities: Array[Entity], components: Array, delta: float) -> void:
##     var velocities = components[0]  # C_Velocity (first in iterate)
##     var transforms = components[1]  # C_Transform (second in iterate)
##
##     for i in entities.size():
##         transforms[i].position += velocities[i].velocity * delta
## [/codeblock]
## [param entities] Array of entities in this batch[br]
## [param components] Array of component arrays, ordered by iterate() definition[br]
## [param delta] Time elapsed since last frame
func process_batch(entities: Array[Entity], components: Array, delta: float) -> void:
	pass # Base implementation - systems can override this


## Runs once after the system has been added to the [World] to setup anything on the system one time[br]
func setup():
	pass # Override in subclasses if needed


## The main processing function for the system.[br]
## This method can be overridden by subclasses to define the system's behavior if using query().[br]
## If using [method System.sub_systems] then this method will not be called.[br]
## [param entity] The [Entity] being processed.[br]
## [param delta] The time elapsed since the last frame.
func process(entity: Entity, delta: float) -> void:
	pass # Override in subclasses - base implementation does nothing


## Sometimes you want to process all entities that match the system's query, this method does that.[br]
## This way instead of running one function for each entity you can run one function for all entities.[br]
## Override this method to implement custom bulk processing logic.[br]
## [param entities] The [Entity]s to process.[br]
## [param delta] The time elapsed since the last frame.
func process_all(entities: Array, delta: float) -> void:
	pass # Base implementation - systems can override this

#endregion Public Methods

#region Private Methods


## INTERNAL: Called by World.add_system() to initialize the system
## DO NOT CALL OR OVERRIDE - this is framework code
func _internal_setup():
	# Determine execution method ONCE at setup - cached for performance
	# Priority: sub_systems > archetype > process_all > process
	# Check subsystems first
	var subs = sub_systems()
	if not subs.is_empty():
		_execution_method = ExecutionMethod.SUBSYSTEMS
	# Check which method is overridden
	elif _is_method_overridden("process_batch"):
		_execution_method = ExecutionMethod.PROCESS_BATCH
	elif _is_method_overridden("process_all"):
		_execution_method = ExecutionMethod.PROCESS_ALL
	elif _is_method_overridden("process"):
		_execution_method = ExecutionMethod.PROCESS
	# else: defaults to PROCESS (does nothing)

	# Call user setup
	setup()

## Process entities in parallel using WorkerThreadPool
func _process_parallel(entities: Array, delta: float) -> void:
	if entities.is_empty():
		return

	# Use OS thread count as fallback since WorkerThreadPool.get_thread_count() doesn't exist
	var worker_count = OS.get_processor_count()
	var batch_size = max(1, entities.size() / worker_count)
	var batches = []
	var tasks = []

	# Split entities into batches
	for i in range(0, entities.size(), batch_size):
		var batch = entities.slice(i, min(i + batch_size, entities.size()))
		batches.append(batch)

	# Submit tasks for each batch
	for batch in batches:
		var task_id = WorkerThreadPool.add_task(_process_batch_callable.bind(batch, delta))
		tasks.append(task_id)

	# Wait for all tasks to complete
	for task_id in tasks:
		WorkerThreadPool.wait_for_task_completion(task_id)


## Process a batch of entities - called by worker threads
func _process_batch_callable(batch: Array, delta: float) -> void:
	for entity in batch:
		process(entity, delta)


## Check if a method is overridden in the subclass (not just inherited from System base class)
func _is_method_overridden(method_name: String) -> bool:
	var script = get_script() as GDScript
	if not script:
		return false

	# Get base script (System class)
	var base_script = script.get_base_script() as GDScript
	if not base_script:
		return false

	# Get all methods from this script
	var this_methods = {}
	for method_info in script.get_script_method_list():
		this_methods[method_info.name] = true

	# Get all methods from base script
	var base_methods = {}
	for method_info in base_script.get_script_method_list():
		base_methods[method_info.name] = true

	# If method exists in this script but NOT in base, it's overridden
	# OR if it exists in both, check if it's defined directly in this script's source
	if method_name in this_methods:
		# Check if method is defined in this script's source code (not just inherited)
		var source_code = script.source_code
		if source_code and source_code.contains("func " + method_name + "("):
			return true

	return false


## Called by World.process() each frame - main entry point for system execution
## [param delta] The time elapsed since the last frame
func _handle(delta: float) -> void:
	# Early exit: system is disabled or paused
	if not active or paused:
		return

	# DEBUG: Track execution time (compiled out in production, disabled via ECS.debug in perf tests)
	var start_time_usec := 0
	assert((func():
		if not ECS.debug:
			return true
		start_time_usec = Time.get_ticks_usec()
		lastRunData = {
			"system_name": get_script().resource_path.get_file().get_basename(),
			"execution_method": ExecutionMethod.keys()[_execution_method],
			"frame_delta": delta,
		}
		return true
	).call())

	# Execute using cached execution method (determined once at setup by World)
	match _execution_method:
		ExecutionMethod.SUBSYSTEMS:
			_run_subsystems(delta)
		ExecutionMethod.PROCESS_BATCH:  # Batch processing with Structure-of-Arrays
			_run_batch_mode(delta)
		ExecutionMethod.PROCESS_ALL:
			_run_process_all_mode(delta)
		ExecutionMethod.PROCESS:
			_run_process_mode(delta)

	# DEBUG: Record execution time (compiled out in production, disabled via ECS.debug in perf tests)
	assert((func():
		if not ECS.debug:
			return true
		var end_time_usec = Time.get_ticks_usec()
		var execution_time_ms = (end_time_usec - start_time_usec) / 1000.0
		lastRunData["execution_time_ms"] = execution_time_ms
		return true
	).call())


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
		var execution_method: ExecutionMethod = subsystem_tuple[2] if subsystem_tuple.size() > 2 else ExecutionMethod.PROCESS

		# DEBUG: Track entity count per subsystem
		var entity_count := 0

		match execution_method:
			ExecutionMethod.PROCESS:
				# Call once per entity
				var matching_entities := subsystem_query.execute() as Array
				entity_count = matching_entities.size()
				for entity in matching_entities:
					subsystem_callable.call(entity, delta)

			ExecutionMethod.PROCESS_ALL:
				# Call once with all entities
				var matching_entities := subsystem_query.execute() as Array
				entity_count = matching_entities.size()
				subsystem_callable.call(matching_entities, delta)

			ExecutionMethod.PROCESS_BATCH:
				# Call once per batch with component columns
				var iterate_comps = subsystem_query._iterate_components

				# EXPLICIT: Must specify iterate() for batch processing mode
				if iterate_comps.is_empty():
					push_error("Subsystem in '%s' uses ExecutionMethod.PROCESS_BATCH but query doesn't call iterate(). You must explicitly specify components: query.with_all([...]).iterate([...])" % get_script().resource_path)
					continue

				var matching_archetypes = subsystem_query.archetypes()
				for archetype in matching_archetypes:
					if archetype.entities.is_empty():
						continue

					entity_count += archetype.entities.size()

					var components = []
					# Gather component columns in iteration order
					for comp_type in iterate_comps:
						var comp_path = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
						components.append(archetype.get_column(comp_path))

					# Call with archetype data
					subsystem_callable.call(archetype.entities, components, delta)

		assert(_update_debug_data(func(): return {
			subsystem_index: {
				"subsystem_index": subsystem_index,
				"entity_count": entity_count,
				"execution_method": ExecutionMethod.keys()[execution_method]
			}
		}), 'Debug data')
		subsystem_index += 1


## Execution path for batch mode
func _run_batch_mode(delta: float) -> void:
	# Lazy initialize query cache
	if not _query_cache:
		_query_cache = query()

	# Lazy initialize component paths from iterate()
	if _batch_component_paths.is_empty():
		var iterate_comps = _query_cache._iterate_components

		# EXPLICIT: Must specify iterate() for batch processing mode
		if iterate_comps.is_empty():
			push_error("System '%s' uses process_batch() but query() doesn't call iterate(). You must explicitly specify components to iterate: query().with_all([...]).iterate([...])" % get_script().resource_path)
			return

		# Cache component resource paths in iteration order
		for comp_type in iterate_comps:
			var comp_path = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
			_batch_component_paths.append(comp_path)

	# Get matching archetypes directly (zero-copy, cache-friendly)
	var matching_archetypes = _query_cache.archetypes()
	var has_entities = false
	var total_entity_count := 0

	# Check if we have any entities at all
	for arch in matching_archetypes:
		if not arch.entities.is_empty():
			has_entities = true
			total_entity_count += arch.entities.size()

	# DEBUG: Track entity count (compiled out in production)
	assert(_update_debug_data(func(): return {
		"entity_count": total_entity_count,
		"archetype_count": matching_archetypes.size()
	}))

	# If no entities and we don't process when empty, exit early
	if not has_entities and not process_empty:
		return

	# If no entities but process_empty is true, call once with empty data
	if not has_entities and process_empty:
		process_batch([], [], delta)
		return

	# Iterate each archetype separately for cache locality
	for arch in matching_archetypes:
		var arch_entities = arch.entities

		# Skip empty archetypes (we only call with actual entities)
		if arch_entities.is_empty():
			continue

		var components = []

		# Gather component columns in iteration order (from iterate() or with_all())
		for comp_path in _batch_component_paths:
			components.append(arch.get_column(comp_path))

		# Call user's process_batch() callback with this archetype's data
		process_batch(arch_entities, components, delta)


## Execution path for standard process() method
func _run_process_mode(delta: float) -> void:
	# Lazy initialize query cache
	if not _query_cache:
		_query_cache = query()

	# Execute query to get matching entities
	var matching_entities := _query_cache.execute()

	# Early exit: no entities and we don't process when empty
	if matching_entities.is_empty() and not process_empty:
		return

	# Process entities one by one using process()
	if matching_entities.size() == 0 and process_empty:
		process(null, delta)
		assert(_update_debug_data(func(): return {"entity_count": 0}))
		return

	# DEBUG: Track entity count (compiled out in production)
	assert(_update_debug_data(func(): return {"entity_count": matching_entities.size()}))

	# Use parallel processing if enabled and we have enough entities
	if parallel_processing and matching_entities.size() >= parallel_threshold:
		assert(_update_debug_data(func(): return {"parallel": true, "threshold": parallel_threshold}))
		_process_parallel(matching_entities, delta)
	else:
		# Otherwise process all the entities sequentially
		assert(_update_debug_data(func(): return {"parallel": false}))
		for entity in matching_entities:
			process(entity, delta)


## Execution path for custom process_all() method
func _run_process_all_mode(delta: float) -> void:
	# Lazy initialize query cache
	if not _query_cache:
		_query_cache = query()

	# Execute query to get matching entities
	var matching_entities := _query_cache.execute()

	# DEBUG: Track entity count (compiled out in production)
	assert(_update_debug_data(func(): return {"entity_count": matching_entities.size()}))

	# Early exit: no entities and we don't process when empty
	if matching_entities.is_empty() and not process_empty:
		return

	# Call user's process_all method directly (entities could be empty if process_empty=true)
	process_all(matching_entities, delta)


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
