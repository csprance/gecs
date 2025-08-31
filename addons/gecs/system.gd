## System[br]
## The base class for all systems within the ECS framework.[br]
##
## Systems contain the core logic and behavior, processing [Entity]s that have specific [Component]s.[br]
## Each system overrides the [method System.query] and returns a query using the [QueryBuilder] [br]
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

## These control when the system should run in relation to other systems.
enum Runs {
	## This system should run before all the systems defined in the array ex: [TransformSystem] means it will run before the [TransformSystem] system runs
	Before,
	## This system should run after all the systems defined in the array ex: [TransformSystem] means it will run after the [TransformSystem] system runs
	After,
}

## What group this system belongs to. Systems can be organized and run by group
@export var group: String = ""
## Determines whether the system should run even when there are no [Entity]s to process.
@export var process_empty := false
## Is this system active. (Will be skipped if false)
@export var active := true
## Enable parallel processing for this system's entities
@export var parallel_processing := false
## Minimum entities required to use parallel processing (performance threshold)
@export var parallel_threshold := 50

## The order in which this system should run (Determined by kahns algorithm and the deps method Runs.Before and Runs.After deps)
var order := 0

## Is this system paused. (Will be skipped if true)
var paused := false

## The [QueryBuilder] object exposed for conveinence to use in the system and to create the query.
var q: QueryBuilder

var systemLogger = GECSLogger.new().domain("System")

var _using_subsystems = true


## Override this method to define the [System]s that this system depends on.[br]
## If not overriden the system will run based on the order of the systems in the [World] [br]
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
	_using_subsystems = false # If this method is not overridden then we are not using sub systems
	return []


## Runs once after the system has been added to the [World] to setup anything on the system one time[br]
func setup():
	pass


## The main processing function for the system.[br]
## This method should be overridden by subclasses to define the system's behavior.[br]
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
func process_all(entities: Array, delta: float) -> bool:
	# If we have no entities and we want to process even when empty do it once and return
	if entities.size() == 0 and process_empty:
		process(null, delta)
		return true
	
	var did_run = false
	
	# Use parallel processing if enabled and we have enough entities
	if parallel_processing and entities.size() >= parallel_threshold:
		did_run = _process_parallel(entities, delta)
	else:
		# otherwise process all the entities sequentially (wont happen if empty array)
		for entity in entities:
			did_run = true
			process(entity, delta)
			entity.on_update(delta)
	
	return did_run


## Process entities in parallel using WorkerThreadPool
func _process_parallel(entities: Array, delta: float) -> bool:
	if entities.is_empty():
		return false
	
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
	
	# Call on_update for all entities on main thread (required for Godot node operations)
	for entity in entities:
		entity.on_update(delta)
	
	return true


## Process a batch of entities - called by worker threads
func _process_batch_callable(batch: Array, delta: float) -> void:
	for entity in batch:
		process(entity, delta)


## Set the query builder to the systems q object.[br]
func set_q():
	if not q:
		q = ECS.world.query


## handles the processing of all [Entity]s that match the system's query [Component]s.[br]
## [param delta] The time elapsed since the last frame.
func _handle(delta: float):
	if not active or paused:
		return
	if _handle_subsystems(delta):
		return
	set_q()
	var did_run := false
	# Query for the entities that match the system's query
	var entities = query().execute()
	did_run = process_all(entities, delta)
	# Avoid calling on_update twice - process_all already calls it


func _handle_subsystems(delta: float):
	var subsystems = sub_systems()
	if not _using_subsystems:
		return false
	set_q()
	var sub_systems_ran = false
	for sub_sys_tuple in subsystems:
		var did_run = false
		sub_systems_ran = true
		var query = sub_sys_tuple[0]
		var sub_sys_process = sub_sys_tuple[1] as Callable
		var should_process_all = sub_sys_tuple[2] if sub_sys_tuple.size() > 2 else false
		var entities = query.execute() as Array[Entity]
		if should_process_all:
			did_run = sub_sys_process.call(entities, delta)
		else:
			# Avoid unnecessary did_run check in tight loop
			if not entities.is_empty():
				did_run = true
				for entity in entities:
					sub_sys_process.call(entity, delta)
		if did_run:
			# Call on_update for all entities that were processed
			for entity in entities:
				entity.on_update(delta)
	return sub_systems_ran
