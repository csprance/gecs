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

## Internal flush mode enum — mirrors @export_enum "PER_SYSTEM","PER_GROUP","MANUAL"
enum FlushMode { PER_SYSTEM, PER_GROUP, MANUAL }

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
@export var command_buffer_flush_mode: FlushMode = FlushMode.PER_SYSTEM

@export_group("Iteration")
## When true (default), entity arrays are copied before iteration to guard against
## mutation skipping from mid-iteration structural changes (add/remove component).
## Set to false when ALL structural changes go through [member cmd] (CommandBuffer),
## since deferred commands never mutate during iteration — skipping the copy entirely.
@export var safe_iteration: bool = true

#endregion Exported Variables

#region Public Variables
## Is this system paused. (Will be skipped if true)
var paused := false
## Optional tick source. If null, system runs every frame (default behavior).
## Multiple systems can share the same [SystemTimer] for synchronized ticking.
## [br]See [method set_tick_rate] for a convenience constructor.
var tick_source: SystemTimer = null

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
		return _world.query if _world else (ECS.world.query if ECS.world else null)
## Command buffer for queuing structural changes (add/remove components, entities, relationships)
## Commands are executed after the system completes based on command_buffer_flush_mode
var cmd: CommandBuffer = null:
	get:
		if cmd == null:
			cmd = CommandBuffer.new(_world if _world else ECS.world)
		return cmd

## Cached query to avoid recreating it every frame (lazily initialized)
var _query_cache: QueryBuilder = null
## Cached component keys for iterate() fast path (script instance ids)
var _component_keys: Array = []
## Cached subsystems array (6.0.0 style)
var _subsystems_cache: Array = []
## -1 = unchecked, 0 = no subsystems, 1 = has subsystems (avoids sub_systems() alloc every frame)
var _has_subsystems_cached: int = -1
## Cached non-structural filter result for _query_cache (-1 = uncached, 0 = false, 1 = true)
var _uses_non_structural_cached: int = -1
## Cached non-structural filter result per subsystem index (built once with _subsystems_cache)
var _subsystem_non_structural_cache: Array[int] = []
## Cached per-subsystem timers (null if no timer for that subsystem index)
var _subsystem_timers_cache: Array = []

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


## Create and assign an interval [SystemTimer] for this system.[br]
## Returns the timer so it can be shared with other systems.[br][br]
## [b]Example — private timer:[/b]
## [codeblock]
## func setup():
##     set_tick_rate(0.5)  # run every 500ms
## [/codeblock]
## [b]Example — shared timer:[/b]
## [codeblock]
## var timer = system_a.set_tick_rate(0.2)
## system_b.tick_source = timer  # both tick together
## [/codeblock]
func set_tick_rate(interval_seconds: float, single_shot: bool = false) -> SystemTimer:
	var timer = SystemTimer.new()
	timer.interval = interval_seconds
	timer.single_shot = single_shot
	tick_source = timer
	return timer


## Check if this system has a command buffer with pending commands
func has_pending_commands() -> bool:
	return cmd != null and not cmd.is_empty()

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
	# Timer gate: only run when tick source fires (null = every frame)
	if tick_source and not tick_source.ticked:
		return
	var start_time_usec := 0
	if ECS.debug:
		start_time_usec = Time.get_ticks_usec()
		lastRunData = {
			"system_name": get_script().resource_path.get_file().get_basename(),
			"frame_delta": delta,
		}
	if _has_subsystems_cached == -1:
		_has_subsystems_cached = 1 if not sub_systems().is_empty() else 0
	if _has_subsystems_cached == 1:
		_run_subsystems(delta)
	else:
		_run_process(delta)
	# Flush command buffer if mode is PER_SYSTEM
	if command_buffer_flush_mode == FlushMode.PER_SYSTEM and has_pending_commands():
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
		_subsystem_non_structural_cache.clear()
		_subsystem_timers_cache.clear()
		for subsystem_tuple in _subsystems_cache:
			var sq := subsystem_tuple[0] as QueryBuilder
			_subsystem_non_structural_cache.append(1 if _query_has_non_structural_filters(sq) else 0)
			_subsystem_timers_cache.append(subsystem_tuple[2] if subsystem_tuple.size() > 2 else null)
	var subsystem_index := 0
	for subsystem_tuple in _subsystems_cache:
		var subsystem_query := subsystem_tuple[0] as QueryBuilder
		var subsystem_callable := subsystem_tuple[1] as Callable
		# Subsystem timer gate: advance and skip if not ticked
		var sub_timer: SystemTimer = _subsystem_timers_cache[subsystem_index]
		if sub_timer:
			sub_timer.advance(delta)
			if not sub_timer.ticked:
				subsystem_index += 1
				continue
		var uses_non_structural := _subsystem_non_structural_cache[subsystem_index] == 1
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
			var enabled_filter = subsystem_query._enabled_filter
			for archetype in subsystem_query.archetypes():
				if archetype.entities.is_empty():
					continue
				# Apply enabled/disabled filter at archetype level via bitset
				var arch_entities: Array[Entity]
				if enabled_filter != null:
					arch_entities = archetype.get_entities_by_enabled_state(enabled_filter)
				else:
					arch_entities = archetype.entities.duplicate()
				if arch_entities.is_empty():
					continue
				total_entity_count += arch_entities.size()
				var components = []
				if not iterate_comps.is_empty():
					if enabled_filter != null:
						# Filtered subset — build columns from entities (can't use archetype columns directly)
						for comp_type in iterate_comps:
							components.append(_build_component_column_from_entities(arch_entities, comp_type))
					else:
						for comp_type in iterate_comps:
							var comp_key = comp_type.get_instance_id() if comp_type is Script else comp_type.get_script().get_instance_id()
							components.append(archetype.get_column(comp_key))
				subsystem_callable.call(arch_entities, components, delta)
			if ECS.debug:
				lastRunData[subsystem_index] = {"subsystem_index": subsystem_index, "entity_count": total_entity_count, "fallback_execute": false}
		subsystem_index += 1


func _run_process(delta: float) -> void:
	if not _query_cache:
		_query_cache = query()
		_uses_non_structural_cached = -1
	if _component_keys.is_empty():
		var iterate_comps = _query_cache._iterate_components
		for comp_type in iterate_comps:
			var comp_key = comp_type.get_instance_id() if comp_type is Script else comp_type.get_script().get_instance_id()
			_component_keys.append(comp_key)
	if _uses_non_structural_cached == -1:
		_uses_non_structural_cached = 1 if _query_has_non_structural_filters(_query_cache) else 0
	var uses_non_structural := _uses_non_structural_cached == 1
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
	# Structural fast path — single pass over archetypes
	var matching_archetypes = _query_cache.archetypes()
	var enabled_filter = _query_cache._enabled_filter
	var processed_any := false
	for arch in matching_archetypes:
		var arch_entities: Array[Entity]
		if enabled_filter != null:
			arch_entities = arch.get_entities_by_enabled_state(enabled_filter)
		else:
			arch_entities = arch.entities
		if arch_entities.is_empty():
			continue
		processed_any = true
		# Snapshot entities to avoid mutation skipping during component add/remove.
		# When safe_iteration is false the system uses CommandBuffer for ALL structural
		# changes so the snapshot copy is unnecessary — use the archetype array directly.
		# When enabled_filter is set, arch_entities is already a new array from get_entities_by_enabled_state.
		var snapshot_entities = arch_entities if enabled_filter != null else (arch_entities.duplicate() if safe_iteration else arch_entities)
		var components = []
		if not iterate_comps.is_empty():
			if enabled_filter != null:
				for comp_type in _query_cache._iterate_components:
					components.append(_build_component_column_from_entities(snapshot_entities, comp_type))
			else:
				for comp_key in _component_keys:
					components.append(arch.get_column(comp_key))
		if parallel_processing and snapshot_entities.size() >= parallel_threshold:
			if ECS.debug:
				lastRunData["parallel"] = true
				lastRunData["threshold"] = parallel_threshold
			_process_parallel(snapshot_entities, components, delta)
		else:
			if ECS.debug:
				lastRunData["parallel"] = false
			process(snapshot_entities, components, delta)
	if not processed_any:
		if process_empty:
			process([], [], delta)
		if ECS.debug:
			lastRunData["entity_count"] = 0
			lastRunData["archetype_count"] = matching_archetypes.size()
			lastRunData["fallback_execute"] = false
		return
	if ECS.debug:
		var total := 0
		for arch in matching_archetypes:
			total += arch.entities.size()
		lastRunData["entity_count"] = total
		lastRunData["archetype_count"] = matching_archetypes.size()
		lastRunData["fallback_execute"] = false


## Determine if a query includes non-structural filters requiring execute() fallback
func _query_has_non_structural_filters(qb: QueryBuilder) -> bool:
	# Structural relationships (exact type-match, wildcard) are handled at archetype level
	# Only post-filter relationships (property-query, script-target) trigger fallback
	if not qb._post_filter_relationships.is_empty():
		return true
	if not qb._post_filter_ex_relationships.is_empty():
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
		for rel in qb._post_filter_relationships:
			if not e.has_relationship(rel):
				include = false; break
		if include:
			for ex_rel in qb._post_filter_ex_relationships:
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
