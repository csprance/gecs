## System[br]
##
## The base class for all systems within the ECS framework.[br]
##
## Systems contain the core logic and behavior, processing [Entity]s that have specific [Component]s.[br]
## Each system overrides the [method System.query] and returns a query using the [QueryBuilder][br]
## exposed as [member System.q] required for it to process an [Entity] and implements the [method System.process] method.[br][br]
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

## The [QueryBuilder] object exposed for convenience to use in the system and to create the query.
var q: QueryBuilder

## Logger for system debugging and tracing
var systemLogger = GECSLogger.new().domain("System")
## Data for debugger and profiling
var lastRunData := {}

## Cached query to avoid recreating it every frame (lazily initialized)
var _query_cache: QueryBuilder = null
## Cached subsystems to avoid recreating them every frame (lazily initialized)
var _subsystems_cache: Array = []
## Set to false when sub_systems() is called and returns empty array
var _has_subsystems: bool = true

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
## If not overridden, the system will run on every update with no entities.
func query() -> QueryBuilder:
	process_empty = true
	return q


## Override this method to define any sub-systems that should be processed by this system.[br]
func sub_systems() -> Array[Array]:
	_has_subsystems = false # If this method is not overridden then we are not using sub systems
	return []


## Runs once after the system has been added to the [World] to setup anything on the system one time[br]
func setup():
	pass


## The main processing function for the system.[br]
## This method can be overridden by subclasses to define the system's behavior if using query().[br]
## If using [method System.sub_systems] then this method will not be called.[br]
## [param entity] The [Entity] being processed.[br]
## [param delta] The time elapsed since the last frame.
func process(entity: Entity, delta: float) -> void:
	assert(
		false,
		"The 'process' method must be overridden in subclasses if it is not using sub systems."
	)


## Sometimes you want to process all entities that match the system's query, this method does that.[br]
## This way instead of running one function for each entity you can run one function for all entities.[br]
## By default this method will run the [method System.process] method for each entity.[br]
## but you can override this method to do something different.[br]
## [param entities] The [Entity]s to process.[br]
## [param delta] The time elapsed since the last frame.
func process_all(entities: Array, delta: float) -> void:
	# If we have no entities and we want to process even when empty do it once and return
	if entities.size() == 0 and process_empty:
		process(null, delta)
		assert(_debug_data({"processed_entities": 0}), 'Debug data')
		return

	# Use parallel processing if enabled and we have enough entities
	if parallel_processing and entities.size() >= parallel_threshold:
		_process_parallel(entities, delta)
	else:
		# otherwise process all the entities sequentially (wont happen if empty array)
		for entity in entities:
			process(entity, delta)
		assert(_debug_data({"processed_entities": entities.size()}), 'Debug data')

#endregion Public Methods

#region Private Methods

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


## Called by World.process() each frame - main entry point for system execution
## [param delta] The time elapsed since the last frame
func _handle(delta: float) -> void:
	# Early exit: system is disabled or paused
	if not active or paused:
		return

	# Ensure query builder is available for both paths
	if not q:
		q = ECS.world.query

	# Path 1: Process using subsystems (if defined)
	if _has_subsystems:
		if _try_run_subsystems(delta):
			return # Subsystems handled everything, we're done

	# Path 2: Process using query() + process() (standard ECS pattern)
	_run_query_system(delta)


## Execution path for subsystems - returns true if subsystems were executed
func _try_run_subsystems(delta: float) -> bool:
	# Lazy initialize subsystems cache
	if _subsystems_cache.is_empty():
		_subsystems_cache = sub_systems()
		# If user didn't override sub_systems(), _has_subsystems is now false
		if not _has_subsystems:
			return false

	# Execute each subsystem
	var subsystem_index := 0
	for subsystem_tuple in _subsystems_cache:
		var subsystem_query := subsystem_tuple[0] as QueryBuilder
		var subsystem_callable := subsystem_tuple[1] as Callable
		var process_all_at_once: bool = subsystem_tuple[2] if subsystem_tuple.size() > 2 else false

		var matching_entities := subsystem_query.execute() as Array

		if process_all_at_once:
			# Call once with all entities
			subsystem_callable.call(matching_entities, delta)
		else:
			# Call once per entity
			for entity in matching_entities:
				subsystem_callable.call(entity, delta)

		assert(_update_debug_data(func(): return {
			subsystem_index: {
				"subsystem_index": subsystem_index,
				"entity_count": matching_entities.size(),
				"process_all": process_all_at_once
			}
		}), 'Debug data')
		subsystem_index += 1

	return true


## Execution path for standard query-based systems
func _run_query_system(delta: float) -> void:
	# Lazy initialize query cache
	if not _query_cache:
		_query_cache = query()

	# Execute query to get matching entities
	var matching_entities := _query_cache.execute()

	# Early exit: no entities and we don't process when empty
	if matching_entities.is_empty() and not process_empty:
		return

	# Process entities (handles empty case, parallel processing, etc.)
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
