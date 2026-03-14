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

@export_group("Command Buffer")
## When to flush the command buffer:
## - PER_SYSTEM: Flush immediately after this system completes (default, safest)
## - PER_GROUP: Flush at the end of the process group (after all systems in the group)
## - MANUAL: Requires manual world.flush_command_buffers() call (for cross-group batching)
@export_enum("PER_SYSTEM", "PER_GROUP", "MANUAL") var command_buffer_flush_mode: String = "PER_SYSTEM"

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
## Command buffer for queuing structural changes (add/remove components, entities, relationships)
## Commands are executed after the system completes based on command_buffer_flush_mode
var cmd: CommandBuffer = null:
	get:
		if cmd == null:
			cmd = CommandBuffer.new(_world if _world else ECS.world)
		return cmd

## Cached query to avoid recreating it every frame (lazily initialized)
var _query_cache: QueryBuilder = null
## Cached component paths for iterate() fast path (6.0.0 style)
var _component_paths: Array[String] = []
## Cached subsystems array (6.0.0 style)
var _subsystems_cache: Array = []

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


## Check if this system has a command buffer with pending commands
func has_pending_commands() -> bool:
	# Accessing cmd will initialize it if needed, then check if it has commands
	return not cmd.is_empty()

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
	if not active or paused:
		return
	var start_time_usec := 0
	if ECS.debug:
		start_time_usec = Time.get_ticks_usec()
		lastRunData = {
			"system_name": get_script().resource_path.get_file().get_basename(),
			"frame_delta": delta,
		}
	var subs = sub_systems()
	if not subs.is_empty():
		_run_subsystems(delta)
	else:
		_run_process(delta)
	# Flush command buffer if mode is PER_SYSTEM
	if command_buffer_flush_mode == "PER_SYSTEM" and has_pending_commands():
		cmd.execute()

	if ECS.debug:
		var end_time_usec = Time.get_ticks_usec()
		lastRunData["execution_time_ms"] = (end_time_usec - start_time_usec) / 1000.0


## UNIFIED execution function for both main systems and subsystems
## This ensures consistent behavior and entity processing logic
## Subsystems and main systems execute IDENTICALLY - no special behavior
## [param query_builder] The query to execute
## [param callable] The function to call with matched entities
## [param delta] Time delta
## [param subsystem_index] Index for debug tracking (-1 for main system)
func _run_subsystems(delta: float) -> void:
	if _subsystems_cache.is_empty():
		_subsystems_cache = sub_systems()
	var subsystem_index := 0
	for subsystem_tuple in _subsystems_cache:
		var subsystem_query := subsystem_tuple[0] as QueryBuilder
		var subsystem_callable := subsystem_tuple[1] as Callable
		var uses_non_structural := _query_has_non_structural_filters(subsystem_query)
		var iterate_comps = subsystem_query._iterate_components
		if uses_non_structural:
			# Gather ALL structural entities first then filter once (avoid per-archetype filtering churn)
			var all_entities: Array[Entity] = []
			for arch in subsystem_query.archetypes():
				if not arch.entities.is_empty():
					all_entities.append_array(arch.entities) # no snapshot to allow mid-frame changes visible to later subsystems
			var filtered = _filter_entities_global(subsystem_query, all_entities)
			if filtered.is_empty():
				if ECS.debug:
					lastRunData[subsystem_index] = {"subsystem_index": subsystem_index, "entity_count": 0, "fallback_execute": true}
				subsystem_index += 1
				continue
			var components := []
			if not iterate_comps.is_empty():
				for comp_type in iterate_comps:
					components.append(_build_component_column_from_entities(filtered, comp_type))
			subsystem_callable.call(filtered, components, delta)
			if ECS.debug:
				lastRunData[subsystem_index] = {"subsystem_index": subsystem_index, "entity_count": filtered.size(), "fallback_execute": true}
		else:
			# Structural fast path archetype iteration
			var total_entity_count := 0
			for archetype in subsystem_query.archetypes():
				if archetype.entities.is_empty():
					continue
				# Snapshot to avoid losing entities during add/remove component archetype moves mid-iteration
				var arch_entities = archetype.entities.duplicate()
				total_entity_count += arch_entities.size()
				var components = []
				if not iterate_comps.is_empty():
					for comp_type in iterate_comps:
						var comp_path = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
						components.append(archetype.get_column(comp_path))
				subsystem_callable.call(arch_entities, components, delta)
			if ECS.debug:
				lastRunData[subsystem_index] = {"subsystem_index": subsystem_index, "entity_count": total_entity_count, "fallback_execute": false}
		subsystem_index += 1


func _run_process(delta: float) -> void:
	if not _query_cache:
		_query_cache = query()
	if _component_paths.is_empty():
		var iterate_comps = _query_cache._iterate_components
		for comp_type in iterate_comps:
			var comp_path = comp_type.resource_path if comp_type is Script else comp_type.get_script().resource_path
			_component_paths.append(comp_path)
	var uses_non_structural := _query_has_non_structural_filters(_query_cache)
	var iterate_comps = _query_cache._iterate_components
	if uses_non_structural:
		# Gather all entities across structural archetypes and then filter once
		var all_entities: Array[Entity] = []
		for arch in _query_cache.archetypes():
			if not arch.entities.is_empty():
				all_entities.append_array(arch.entities)
		if all_entities.is_empty():
			if process_empty:
				process([], [], delta)
			return
		var filtered = _filter_entities_global(_query_cache, all_entities)
		if filtered.is_empty():
			if process_empty:
				process([], [], delta)
			return
		var components := []
		if not iterate_comps.is_empty():
			for comp_type in iterate_comps:
				components.append(_build_component_column_from_entities(filtered, comp_type))
		if parallel_processing and filtered.size() >= parallel_threshold:
			_process_parallel(filtered, components, delta)
		else:
			process(filtered, components, delta)
		if ECS.debug:
			lastRunData["entity_count"] = filtered.size()
			lastRunData["archetype_count"
				] = _query_cache.archetypes().size()
			lastRunData["fallback_execute"] = true
			lastRunData["parallel"] = parallel_processing and filtered.size() >= parallel_threshold
		return
	# Structural fast path
	var matching_archetypes = _query_cache.archetypes()
	var has_entities = false
	var total_entity_count := 0
	for arch in matching_archetypes:
		if not arch.entities.is_empty():
			has_entities = true
			total_entity_count += arch.entities.size()
	if ECS.debug:
		lastRunData["entity_count"] = total_entity_count
		lastRunData["archetype_count"] = matching_archetypes.size()
		lastRunData["fallback_execute"] = false
	if not has_entities and not process_empty:
		return
	if not has_entities and process_empty:
		process([], [], delta)
		return
	for arch in matching_archetypes:
		var arch_entities = arch.entities
		if arch_entities.is_empty():
			continue
		# Snapshot structural entities to avoid mutation skipping during component add/remove
		var snapshot_entities = arch_entities.duplicate()
		var components = []
		if not iterate_comps.is_empty():
			for comp_path in _component_paths:
				components.append(arch.get_column(comp_path))
		if parallel_processing and snapshot_entities.size() >= parallel_threshold:
			if ECS.debug:
				lastRunData["parallel"] = true
				lastRunData["threshold"] = parallel_threshold
			_process_parallel(snapshot_entities, components, delta)
		else:
			if ECS.debug:
				lastRunData["parallel"] = false
			process(snapshot_entities, components, delta)


## Determine if a query includes non-structural filters requiring execute() fallback
func _query_has_non_structural_filters(qb: QueryBuilder) -> bool:
	if not qb._relationships.is_empty():
		return true
	if not qb._exclude_relationships.is_empty():
		return true
	if not qb._groups.is_empty():
		return true
	if not qb._exclude_groups.is_empty():
		return true
	# Component property queries (ensure actual queries, not placeholders)
	if not qb._all_components_queries.is_empty():
		for query in qb._all_components_queries:
			if not query.is_empty():
				return true
	if not qb._any_components_queries.is_empty():
		for query in qb._any_components_queries:
			if not query.is_empty():
				return true
	return false


## Build component arrays for iterate() when falling back to execute() result (no archetype columns)
func _build_component_column_from_entities(entities: Array[Entity], comp_type) -> Array:
	var out := []
	for e in entities:
		if e == null:
			out.append(null)
			continue
		var comp = e.get_component(comp_type)
		out.append(comp)
	return out


## Filter entities in an archetype for non-structural query criteria (relationships/groups/property queries)
## Filter a flat entity array for non-structural criteria
func _filter_entities_global(qb: QueryBuilder, entities: Array[Entity]) -> Array[Entity]:
	var result: Array[Entity] = []
	for e in entities:
		if e == null:
			continue
		var include := true
		for rel in qb._relationships:
			if not e.has_relationship(rel):
				include = false; break
		if include:
			for ex_rel in qb._exclude_relationships:
				if e.has_relationship(ex_rel):
					include = false; break
		if include and not qb._groups.is_empty():
			for g in qb._groups:
				if not e.is_in_group(g):
					include = false; break
		if include and not qb._exclude_groups.is_empty():
			for g in qb._exclude_groups:
				if e.is_in_group(g):
					include = false; break
		if include and not qb._all_components_queries.is_empty():
			for i in range(qb._all_components.size()):
				if i >= qb._all_components_queries.size():
					break
				var comp_type = qb._all_components[i]
				var query = qb._all_components_queries[i]
				if not query.is_empty():
					var comp = e.get_component(comp_type)
					if comp == null or not ComponentQueryMatcher.matches_query(comp, query):
						include = false; break
		if include and not qb._any_components_queries.is_empty():
			var any_match := qb._any_components_queries.is_empty()
			for i in range(qb._any_components.size()):
				if i >= qb._any_components_queries.size():
					break
				var comp_type = qb._any_components[i]
				var query = qb._any_components_queries[i]
				if not query.is_empty():
					var comp = e.get_component(comp_type)
					if comp and ComponentQueryMatcher.matches_query(comp, query):
						any_match = true; break
			if not any_match and not qb._any_components.is_empty():
				include = false
		if include:
			result.append(e)
	return result


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
