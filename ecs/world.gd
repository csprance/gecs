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
	entity: Entity,
	component: Variant,
	property: String,
	new_value: Variant,
	old_value: Variant,
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
## Per-event observer dispatch index. Key = [enum Observer.Event] int flag. Value = Array of
## dispatch entries: [code]{observer, query, callable, watched_paths, is_monitor, ...}[/code].
## Rebuilt per observer by [method _register_observer_entries] / [method _unregister_observer_entries].
var _obs_entries_by_event: Dictionary = {}
## Per-custom-event observer dispatch index. Key = [StringName]. Same entry shape as
## [member _obs_entries_by_event].
var _obs_entries_by_custom_event: Dictionary = {}
## All observer/sub-observer entries belonging to a given [Observer], keyed by observer instance.
## Used for O(1) cleanup on [method remove_observer].
var _obs_entries_by_observer: Dictionary = {}
## Prebuilt deduped list of monitor entries (is_monitor == true), maintained
## copy-on-write at (un)registration so _evaluate_monitors_for_entity allocates
## nothing per event. Empty when no monitors are registered — the common case.
var _monitor_entries: Array = []
## All the [System]s by group Dictionary[String, Array[System]]
var systems_by_group: Dictionary[String, Array] = {}
## All the [System]s in the world flattened into a single array
var systems: Array[System]:
	get:
		var all_systems: Array[System] = []
		for group in systems_by_group.keys():
			all_systems.append_array(systems_by_group[group])
		return all_systems
## ID → [Entity] registry. Keys are int generational handles ([member Entity.id]) —
## covers both locally allocated handles and pre-assigned foreign ones
## (network replication / deserialization). Prevents duplicate IDs and enables
## O(1) ID lookups. Stale handles are never present: a recycled slot has a
## bumped generation and therefore a different int id.
var entity_id_registry: Dictionary = {}  # int (id) -> Entity
## Generation counter per slot index for the handle allocator.
## handle = index | (generation << 32).
var _slot_generations: PackedInt64Array = PackedInt64Array()
## Recycled slot indices available for reuse (LIFO).
var _free_slots: Array[int] = []
## Alias registry: StringName → Entity. Aliases are optional semantic NAMES
## ("singleton_player") — the identity is the int handle. Same-alias adds
## replace the existing entity (singleton pattern).
var _entity_aliases: Dictionary = {}
## ARCHETYPE STORAGE - Entity storage by component signature for O(1) queries
## Maps archetype signature (FNV-1a hash) -> Archetype instance
var archetypes: Dictionary = {}  # int -> Archetype
## Fast lookup: Entity -> its current Archetype
var entity_to_archetype: Dictionary = {}  # Entity -> Archetype
## The [QueryBuilder] instance for this world used to build and execute queries.
## Builders detect stale cached results by comparing [member cache_version] at
## execute() time, so no signal connection is made here. (Connecting each vended
## builder to [signal cache_invalidated] would strongly retain every builder ever
## created and fan every structural change out to all of them.)
var query: QueryBuilder:
	get:
		return QueryBuilder.new(self)

## Relation-type archetype index: maps relation resource_path -> { archetype_signature -> Archetype }
## Enables O(1) wildcard relationship queries (find all archetypes with any (RelationType, *) pair)
var _relation_type_archetype_index: Dictionary = {}  # String -> Dictionary[int, Archetype]
## Logger for the world to only log to a specific domain
var _worldLogger = GECSLogger.new().domain("World")
## Cache for commonly used query results - stores matching archetypes, not entities.
## Maintained INCREMENTALLY: entity moves between existing archetypes never touch it;
## archetype creation appends to matching entries (_register_new_archetype) and
## archetype deletion erases from them (_delete_archetype). Only purge()/compact()
## clear it wholesale.
var _query_archetype_cache: Dictionary = {}  # query_sig -> Array[Archetype]
## Match terms stored per cached query so new archetypes can be tested against
## cached queries at creation time. Same key space as _query_archetype_cache.
## Value: [all_ids, any_ids, exclude_ids, rel_slot_keys, ex_rel_slot_keys,
##         wildcard_rel_types, wildcard_ex_rel_types]
var _query_cache_terms: Dictionary = {}
## Track cache hits for performance monitoring
var _cache_hits: int = 0
var _cache_misses: int = 0
## Track cache invalidations for debugging
var _cache_invalidation_count: int = 0
## Monotonic membership version — incremented whenever any entity's archetype
## membership changes (component/relationship add/remove, entity add/remove,
## enabled flips). QueryBuilder compares this to detect stale cached execute()
## results without relying on signal delivery.
var cache_version: int = 0
## Monotonic archetype-set version — incremented only when an archetype is
## created or deleted. Diagnostic counter for the incremental cache maintenance.
var archetype_set_version: int = 0
## CHANGE DETECTION: the world-visible write clock (mirrors
## Archetype.global_change_tick; advanced once per system run).
var change_tick: int:
	get:
		return Archetype.global_change_tick
## Component keys some query tracks via .changed(). Empty (the common case)
## means property writes pay only one is_empty() check for change detection.
var _change_tracked_keys: Dictionary = {}
var _cache_invalidation_reasons: Dictionary = {}  # reason -> count
## Global cache: script_instance_id (int) -> Script (loaded once, reused forever)
var _component_script_cache: Dictionary = {}  # int -> Script
## OPTIMIZATION: Depth counter to suppress cache invalidation during batch operations.
## > 0 means we are inside a batch; invalidation is deferred until _end_suppress().
var _suppress_invalidation_depth: int = 0
var _pending_invalidation: bool = false
## Guard flag: true when a batch relationship handler is emitting per-entity signals.
## Prevents _on_entity_relationship_added/removed from doing redundant archetype moves.
var _in_batch_relationship_emit: bool = false
## Deferred archetype moves: while true, structural handlers queue touched entities
## instead of moving them per operation. CommandBuffer.execute() opens this window so
## a remove+add state transition costs ONE archetype move instead of two.
var _defer_archetype_moves: bool = false
## Entities with a pending deferred archetype move, in first-touch order.
var _deferred_move_entities: Array = []
var _deferred_move_set: Dictionary = {}  # Entity -> true
## Count of systems currently mid-iteration with safe_iteration=false (zero-copy).
## Structural mutation while this is > 0 (outside a deferred-move window) can skip
## entities via swap-remove — flagged with a debug-mode error in structural handlers.
var _iteration_depth: int = 0
## One-shot guard: fires push_error once when archetype count first exceeds 500 in debug mode
var _archetype_explosion_warned: bool = false
## Frame + accumulated performance metrics (debug-only)
var _perf_metrics := {"frame": {}, "accum": {}}  # Per-frame aggregated timings  # Long-lived totals (cleared manually)
## Opt-in query-timing instrumentation. Even with ECS.debug on, [method perf_mark]
## and its per-query timestamp reads stay off unless this is set — nothing in the
## framework consumes the aggregates, so profiling tooling enables it explicitly
## before reading [method perf_get_frame_metrics] / [method perf_get_accum_metrics].
var perf_instrumentation: bool = false
## Debugger ad-hoc query runner: name -> resource path of every global class
## (built once, no loading) and a lazily-populated name -> loaded Script cache.
## Only classes actually referenced in a typed query are loaded, so broken or
## editor-only global scripts are never touched.
var _debugger_class_paths: Dictionary = {}
var _debugger_class_scripts: Dictionary = {}
## Per-group accumulated seconds since the last telemetry sample. Telemetry to the
## debugger is throttled to the subscribed rate (GECSEditorDebuggerMessages
## .telemetry_interval) instead of firing every frame — peaks are preserved by the
## runtime-side min/max/avg aggregation in System, which runs every frame regardless.
var _telemetry_accum: Dictionary = {}
## Queue of systems waiting for setup after ECS.world is assigned
var _deferred_setup_systems: Array[System] = []
## Per-group unique SystemTimers to advance each frame (rebuilt lazily when _timers_dirty)
var _group_timers: Dictionary = {}  # group_name -> Array[SystemTimer]
## True when systems have been added/removed and _group_timers needs rebuilding
var _timers_dirty: bool = true


## Internal perf helper (debug only)
func perf_mark(key: String, duration_usec: int, extra: Dictionary = {}) -> void:
	if not (ECS.debug and perf_instrumentation):
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
	if ECS.debug and perf_instrumentation:
		_perf_metrics.frame.clear()


## Get a copy of current frame metrics
func perf_get_frame_metrics() -> Dictionary:
	return _perf_metrics.frame.duplicate(true)


## Get a copy of accumulated metrics
func perf_get_accum_metrics() -> Dictionary:
	return _perf_metrics.accum.duplicate(true)


## Reset accumulated metrics
func perf_reset_accum() -> void:
	if ECS.debug and perf_instrumentation:
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
	# NOTE: Observers register BEFORE scene-tree entities load, so an observer with
	# yield_existing=true iterates an empty entities list and retro-fires nothing.
	# That's the intended behavior — entities added after the observer registers are
	# delivered through normal dispatch (component_added → _dispatch_observer_event),
	# so every scene-tree entity still triggers the observer via its structural add.
	# yield_existing only matters for observers added at runtime AFTER entities already
	# exist (where natural dispatch wouldn't cover them).
	var _observers = get_node(system_nodes_root).find_children("*", "Observer") as Array[Observer]
	add_observers(_observers)
	_worldLogger.debug("_initialize Added Observers from Scene Tree: ", _observers)

	# Add entities from the scene tree
	var _entities = get_node(entity_nodes_root).find_children("*", "Entity") as Array[Entity]
	add_entities(_entities)
	_worldLogger.debug("_initialize Added Entities from Scene Tree: ", _entities)

	if ECS.debug:
		# The gecs capture is registered once on the ECS autoload (ECS._ready) so it
		# survives world swaps. Re-resolve the transport, then announce this world:
		# READY lets a late-connecting tab (re)subscribe, and world_init hands the tab
		# a fresh world context if we are already subscribed.
		GECSEditorDebuggerMessages.refresh_attached()
		GECSEditorDebuggerMessages.ready()
		if GECSEditorDebuggerMessages.attached:
			assert(GECSEditorDebuggerMessages.world_init(self), "")


## Finalize deferred system setup after ECS.world is set.
## All systems defer their setup() until this method is called to ensure
## setup() methods can safely access both _world and ECS.world.
func finalize_system_setup() -> void:
	if _deferred_setup_systems.is_empty():
		return

	(
		_worldLogger
		.debug(
			"finalize_system_setup Executing deferred setup for ",
			_deferred_setup_systems.size(),
			" systems",
		)
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
	# Decide once whether this frame emits a telemetry sample. Throttled to the
	# subscribed rate so an attached tab doesn't cost a full per-system message set
	# every frame (min/max/avg still aggregate every frame inside System._handle).
	var telemetry_due := false
	if (
		ECS.debug
		and GECSEditorDebuggerMessages.attached
		and GECSEditorDebuggerMessages.telemetry_active
	):
		var acc: float = _telemetry_accum.get(group, 0.0) + delta
		if acc >= GECSEditorDebuggerMessages.telemetry_interval:
			telemetry_due = true
			acc = 0.0
		_telemetry_accum[group] = acc
	if systems_by_group.has(group):
		# Advance all unique timers for this group BEFORE running systems
		if _timers_dirty:
			_rebuild_group_timers()
		if _group_timers.has(group):
			for timer in _group_timers[group]:
				timer.advance(delta)
		var system_index = 0
		# Index iteration with a slot re-check: remove_system() erases from this
		# live array, and a for-in would skip the system that shifts into the
		# vacated slot when a system removes itself (or an earlier peer)
		# mid-frame. Costs one comparison per system, no per-frame copy.
		var group_systems: Array = systems_by_group[group]
		var slot := 0
		while slot < group_systems.size():
			var system = group_systems[slot]
			if system.active:
				system._handle(delta)
				if telemetry_due:
					# Add execution order to last run data
					system.lastRunData["execution_order"] = system_index
					assert(
						GECSEditorDebuggerMessages.system_last_run_data(system, system.lastRunData),
						"",
					)
					system_index += 1
			# Advance only if the slot still holds this system; an erase at or
			# before it shifted the next system into the slot.
			if slot < group_systems.size() and group_systems[slot] == system:
				slot += 1

		# Flush PER_GROUP command buffers after all systems in the group complete.
		# Re-check the key: a system that removed itself above may have emptied the
		# group, which erases it from the dictionary mid-frame. Same slot re-check
		# as above in case a flushed command removes a system.
		if systems_by_group.has(group):
			var flush_systems: Array = systems_by_group[group]
			var flush_slot := 0
			while flush_slot < flush_systems.size():
				var system = flush_systems[flush_slot]
				if (
					system.command_buffer_flush_mode == System.FlushMode.PER_GROUP
					and system.has_pending_commands()
				):
					system.cmd.execute()
				if flush_slot < flush_systems.size() and flush_systems[flush_slot] == system:
					flush_slot += 1
	if telemetry_due:
		assert(GECSEditorDebuggerMessages.process_world(delta, group), "")


## Manually flush all command buffers with MANUAL flush mode.[br]
## This executes all queued commands from systems that use command_buffer_flush_mode = FlushMode.MANUAL.[br]
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
			if (
				system.command_buffer_flush_mode == System.FlushMode.MANUAL
				and system.has_pending_commands()
			):
				system.cmd.execute()
	# Observers with MANUAL flush mode share the same drain point — otherwise their
	# queued commands would never execute.
	for obs in observers:
		if (
			obs.command_buffer_flush_mode == Observer.FlushMode.MANUAL
			and obs.has_pending_commands()
		):
			obs.cmd.execute()


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
	# Identity: keep a pre-assigned nonzero id verbatim (deserialization /
	# network replication); otherwise allocate a generational handle.
	if entity.id == 0:
		entity.id = _alloc_entity_id()
	elif entity_id_registry.has(entity.id):
		var existing_entity = entity_id_registry[entity.id]
		if existing_entity != entity:
			(
				_worldLogger
				.debug(
					"ID collision detected, replacing entity: ",
					existing_entity.name,
					" with: ",
					entity.name,
				)
			)
			remove_entity(existing_entity)

	# Register this entity's ID
	entity_id_registry[entity.id] = entity

	# Register the optional semantic alias (singleton pattern: same alias replaces)
	if entity.alias != &"":
		var alias_holder = _entity_aliases.get(entity.alias)
		if alias_holder != null and is_instance_valid(alias_holder) and alias_holder != entity:
			(
				_worldLogger
				.debug(
					"Alias collision detected, replacing entity: ",
					alias_holder.name,
					" with: ",
					entity.name,
				)
			)
			remove_entity(alias_holder)
		_entity_aliases[entity.alias] = entity

	# Stabilize target IDs before archetype key/signature generation so entities
	# with pre-registered relationship targets don't get stale entity#0 slot keys.
	for relationship in entity.relationships:
		var rel_target = relationship.target
		if typeof(rel_target) == TYPE_OBJECT and not is_instance_valid(rel_target):
			continue  # dangling target; `is` errors on a freed operand
		if rel_target is Entity:
			_ensure_entity_id(rel_target)

	# Update index
	_worldLogger.debug("add_entity Adding Entity to World: ", entity)

	# Track this entity: structural mutations notify the world via DIRECT calls
	# (entity._world backref) — replaces six signal connects per entity.
	entity._world = self

	#  Add the entity to the tree if it's not already there after hooking up tracking
	# This ensures that any _ready methods on the entity or its components are called after setup
	if add_to_tree and not entity.is_inside_tree():
		get_node(entity_nodes_root).add_child(entity)

	# add entity to our list (index tracked for O(1) swap-removal)
	entity._entities_index = entities.size()
	entities.append(entity)

	# OPTIMIZATION: Suppress cache invalidation during entity initialization —
	# one membership bump for the entire add_entity operation.
	_begin_suppress()

	# Initialize the entity BEFORE inserting it into an archetype. The entity is
	# not yet tracked in entity_to_archetype, so the per-component component_added
	# emits skip all archetype work (observers/monitors still fire per component) —
	# spawning an entity with N components costs ZERO archetype transitions here.
	if not Engine.is_editor_hint():
		entity._initialize(components if components else [])

	# ARCHETYPE: Single insert with the final signature (components + relationships
	# all present) — no intermediate archetypes are ever created.
	_add_entity_to_archetype(entity)

	# Re-enable and perform a single membership bump for the entire add_entity operation
	_end_suppress()

	entity_added.emit(entity)

	# All the entities are ready so we should run the pre-processors now
	for processor in ECS.entity_preprocessors:
		processor.call(entity)

	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
		assert(GECSEditorDebuggerMessages.entity_added(entity, add_to_tree), "")


## Adds multiple entities to the world.[br]
## [param entities] An array of entities to add.
## [param components] The optional list of [Component] to add to the entity.[br]
## [b]Example:[/b]
##      [codeblock]world.add_entities([player_entity, enemy_entity], [component_a])[/codeblock]
func add_entities(_entities: Array, components = null):
	# OPTIMIZATION: Batch processing to reduce cache invalidations
	# Suppress individual invalidations during batch; _end_suppress fires one deferred call.
	_begin_suppress()

	# Process all entities
	for _entity in _entities:
		add_entity(_entity, components)

	_end_suppress()


## Removes an [Entity] and all its components from the world.[br]
## [br]
## [b]Teardown order (guaranteed):[/b][br]
## 1. Entity signals are disconnected first to prevent re-entrancy during observer callbacks.[br]
## 2. Observers with [code].on_removed()[/code] fire via [method Observer.each] for each component — entity is still valid.[br]
## 3. Entity is removed from the entity list and archetype.[br]
## 4. [method Entity.on_destroy] is called, then [code]queue_free[/code].[br]
## [br]
## [b]Observer callback safety:[/b] It is safe to read [param entity] state inside a REMOVED callback.[br]
## The order in which components trigger the REMOVED event is unspecified.[br]
## [br]
## [param entity] The [Entity] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_entity(player_entity)[/codeblock]
func remove_entity(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	entity = entity as Entity

	for processor in ECS.entity_postprocessors:
		processor.call(entity)

	# REMOVE policy: Clean up relationships pointing TO this entity from other entities
	_cleanup_relationships_to_target(entity)

	# Stop tracking before notifying observers to prevent re-entrancy:
	# if a REMOVED observer callback calls entity.remove_component() as a side effect,
	# the world must not be re-notified or it would double-notify observers watching
	# that component. Clearing the backref makes the entity's direct calls no-ops.
	entity._world = null

	# Emit component_removed for each component before teardown
	# so observers learn about removal when an entity is destroyed
	for comp in entity.components.values():
		component_removed.emit(entity, comp)
		_handle_observer_component_removed(entity, comp)

	# Unmatch monitor queries this entity was in — fires on_unmatch and clears membership
	_drop_entity_from_monitors(entity)

	entity_removed.emit(entity)
	_worldLogger.debug("remove_entity Removing Entity: ", entity)
	# O(1) swap-removal from the entity list (order is NOT preserved)
	var erase_idx: int = entity._entities_index
	if erase_idx >= 0 and erase_idx < entities.size() and entities[erase_idx] == entity:
		var last := entities.size() - 1
		# The tail can hold dangling refs from entities freed outside
		# remove_entity; the typed array refuses them on write (leaving this
		# entity behind in its slot), so drop them before swapping.
		while last > erase_idx and not is_instance_valid(entities[last]):
			entities.remove_at(last)
			last -= 1
		if erase_idx != last:
			var moved: Entity = entities[last]
			entities[erase_idx] = moved
			moved._entities_index = erase_idx
		entities.remove_at(last)
		entity._entities_index = -1
	else:
		# Fallback for entities with a stale/missing index (shouldn't happen)
		var found_idx = entities.find(entity)
		if found_idx >= 0:
			entities.remove_at(found_idx)
		else:
			_worldLogger.warning("remove_entity: entity not found in entities array: ", entity)

	# Remove from ID registry and recycle locally-allocated handles
	if entity.id != 0 and entity_id_registry.get(entity.id) == entity:
		entity_id_registry.erase(entity.id)
		_free_entity_id(entity.id)

	# Remove from alias registry
	if entity.alias != &"" and _entity_aliases.get(entity.alias) == entity:
		_entity_aliases.erase(entity.alias)

	# ARCHETYPE: Remove entity from archetype system (parallel)
	_remove_entity_from_archetype(entity)

	# Notify debugger before freeing (entity must still be valid)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
		var path = entity.get_path() if entity.is_inside_tree() else str(entity)
		assert(GECSEditorDebuggerMessages.entity_removed(entity.get_instance_id(), path), "")

	# Destroy entity normally
	entity.on_destroy()
	if entity.is_inside_tree():
		entity.queue_free()
	else:
		entity.free()


## Removes an Array of [Entity] from the world.[br]
## [param entity] The Array of [Entity] to remove.[br]
## [b]Example:[/b]
##      [codeblock]world.remove_entities([player_entity, other_entity])[/codeblock]
func remove_entities(_entities: Array) -> void:
	# OPTIMIZATION: Batch processing to reduce cache invalidations
	# Suppress individual invalidations during batch; _end_suppress fires one deferred call.
	_begin_suppress()

	# Process all entities
	for _entity in _entities:
		remove_entity(_entity)

	_end_suppress()


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

	# Stop tracking — the entity's direct world calls become no-ops while disabled.
	entity._world = null
	entity.on_disable()
	entity.set_process(false)
	entity.set_physics_process(false)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
		assert(GECSEditorDebuggerMessages.entity_disabled(entity), "")
	return entity


## Disable an Array of [Entity] from the world. Disabled entities don't run process or physics,[br]
## are hidden and removed the entities list[br]
## [param entity] The [Entity] to disable.[br]
## [b]Example:[/b]
##      [codeblock]world.disable_entities([player_entity, other_entity])[/codeblock]
func disable_entities(_entities: Array) -> void:
	# CACHE-04: Suppress N individual disable_entity() invalidations; _end_suppress fires once.
	_begin_suppress()
	for _entity in _entities:
		disable_entity(_entity)
	_end_suppress()


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

	# Resume tracking — structural mutations notify the world directly again.
	entity._world = self

	if components:
		entity.add_components(components)

	entity.set_process(true)
	entity.set_physics_process(true)
	entity.on_enable()
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
		assert(GECSEditorDebuggerMessages.entity_enabled(entity), "")


## Find an entity by its int handle id.
## Stale handles (freed or recycled slots) return null — the registry never
## contains them because a recycled slot carries a bumped generation.
## [param id] The handle to search for
## [return] The Entity with matching ID, or null if not found
func get_entity_by_id(id: int) -> Entity:
	return entity_id_registry.get(id, null)


## Check if an entity with the given handle id exists (i.e. the handle is live).
func has_entity_with_id(id: int) -> bool:
	return id in entity_id_registry


## True when the handle refers to a live entity in this world.
func is_alive(id: int) -> bool:
	return id in entity_id_registry


## Find an entity by its semantic alias (see [member Entity.alias]).
func get_entity_by_alias(alias: StringName) -> Entity:
	var entity = _entity_aliases.get(alias)
	return entity if entity != null and is_instance_valid(entity) else null


## Check if an entity is registered under the given alias.
func has_entity_with_alias(alias: StringName) -> bool:
	return get_entity_by_alias(alias) != null


## Register (or re-point) a semantic alias for an entity at runtime.
func register_alias(alias: StringName, entity: Entity) -> void:
	_entity_aliases[alias] = entity


## Remove a semantic alias.
func unregister_alias(alias: StringName) -> void:
	_entity_aliases.erase(alias)


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
	_timers_dirty = true
	system_added.emit(system)

	# If ECS.world is already this world, setup immediately since finalize_system_setup()
	# has already run. Otherwise defer until finalize_system_setup() is called.
	if ECS.world == self:
		system._internal_setup()
		_worldLogger.trace("add_system Immediate setup for system: ", system)
	else:
		_deferred_setup_systems.append(system)
		_worldLogger.trace("add_system Deferring setup for system: ", system)

	if topo_sort:
		ArrayExtensions.topological_sort(systems_by_group)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
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
	if systems_by_group.has(system.group):
		systems_by_group[system.group].erase(system)
		if systems_by_group[system.group].size() == 0:
			systems_by_group.erase(system.group)
	_timers_dirty = true
	system_removed.emit(system)
	# Update index
	system.queue_free()
	if topo_sort:
		ArrayExtensions.topological_sort(systems_by_group)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
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
		# Iterate a copy: remove_system erases from the live array (and can erase
		# the group key), which would otherwise skip every other system.
		for system in systems_by_group[group].duplicate():
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
		# Entities freed outside remove_entity leave dangling refs that the typed
		# remove_entity parameter would reject at the call boundary.
		if is_instance_valid(entity):
			remove_entity(entity)
	# Compact away those dangling refs, re-syncing the swap-removal index for
	# surviving (kept) entities.
	var live_entities: Array[Entity] = []
	for entity in entities:
		if is_instance_valid(entity):
			entity._entities_index = live_entities.size()
			live_entities.append(entity)
	entities = live_entities

	# Clear relationship indexes after purging entities
	_relation_type_archetype_index.clear()
	if keep.is_empty():
		# Reset the handle allocator — no live handles remain to alias against
		_slot_generations = PackedInt64Array()
		_free_slots.clear()
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

	_invalidate_cache_full("purge")

	# remove itself
	if should_free:
		queue_free()


## Delete all EMPTY archetypes and their transition edges, reclaiming memory.
## Empty archetypes are normally kept so spawn/despawn churn reuses them (and
## their O(1) transition edges). Call this at a known quiet point (level change,
## loading screen) if long play sessions accumulate many stale compositions.
## Returns the number of archetypes deleted.
func compact() -> int:
	var to_delete: Array = []
	for archetype in archetypes.values():
		if archetype.is_empty():
			to_delete.append(archetype)
	for archetype in to_delete:
		_delete_archetype(archetype)
	if not to_delete.is_empty():
		_invalidate_cache_full("compact")
		_archetype_explosion_warned = false
	return to_delete.size()


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

#region Timer Management


## Rebuild the per-group unique timer sets from current systems.
## Called lazily when _timers_dirty is true (after add_system / remove_system).
func _rebuild_group_timers() -> void:
	_group_timers.clear()
	for group_key in systems_by_group.keys():
		var seen := {}  # instance_id -> true (dedup shared timers)
		var timers: Array = []
		for system in systems_by_group[group_key]:
			if system.tick_source and not seen.has(system.tick_source.get_instance_id()):
				seen[system.tick_source.get_instance_id()] = true
				timers.append(system.tick_source)
		if not timers.is_empty():
			_group_timers[group_key] = timers
	_timers_dirty = false


#endregion Timer Management

#region Signal Callbacks


## [signal Entity.component_added] Callback when a component is added to an entity.[br]
## [param entity] The entity that had a component added.[br]
## [param component] The resource path of the added component.
func _on_entity_component_added(entity: Entity, component: Resource) -> void:
	# ARCHETYPE: Move entity to new archetype
	if entity_to_archetype.has(entity):
		if _defer_archetype_moves:
			# Inside a CommandBuffer flush — coalesce to one move per entity at window close.
			_queue_deferred_move(entity)
		else:
			if ECS.debug and _iteration_depth > 0:
				_warn_structural_change_during_iteration("add_component", entity)
			var old_archetype = entity_to_archetype[entity]
			var comp_key = component.get_script().get_instance_id()
			var new_archetype = _move_entity_to_new_archetype_fast(
				entity,
				old_archetype,
				comp_key,
				true,
			)
		# Membership changed — bump so cached execute() results know they're stale.
		# The query→archetype cache itself stays valid (maintained incrementally).
		_bump_membership("entity_component_added")

	# Emit Signal
	component_added.emit(entity, component)
	_handle_observer_component_added(entity, component)
	if (
		not _monitor_entries.is_empty()
		and component != null
		and component.get_script() != null
	):
		_evaluate_monitors_for_entity(entity, component.get_script().resource_path)
	# (Property changes arrive via the entity's direct _world call — no signal hop.)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
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
	new_value: Variant,
) -> void:
	# CHANGE DETECTION: stamp the row version (one dict check when unused)
	if not _change_tracked_keys.is_empty():
		_mark_component_changed(entity, component)
	# Notify the World to trigger observers
	_handle_observer_component_changed(entity, component, property_name, new_value, old_value)
	# Re-evaluate monitor queries whose filters include property-query criteria on this
	# component. Monitor sensitivity is keyed by component script path; property-query
	# components live in the same path so this catches "hp dropped below threshold"-style
	# transitions without any structural mutation.
	if (
		not _monitor_entries.is_empty()
		and component != null
		and component.get_script() != null
	):
		_evaluate_monitors_for_entity(entity, component.get_script().resource_path)
	# ARCHETYPE: No cache invalidation - property changes don't affect archetype membership
	# Send the message to the debugger if we're in debug
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.property_changes_active:
		assert(
			(
				GECSEditorDebuggerMessages
				.entity_component_property_changed(
					entity,
					component,
					property_name,
					old_value,
					new_value,
				)
			),
			"",
		)


## [signal Entity.component_removed] Callback when a component is removed from an entity.[br]
## [param entity] The entity that had a component removed.[br]
## [param component] The resource path of the removed component.
func _on_entity_component_removed(entity, component: Resource) -> void:
	if entity_to_archetype.has(entity):
		if _defer_archetype_moves:
			_queue_deferred_move(entity)
		else:
			if ECS.debug and _iteration_depth > 0:
				_warn_structural_change_during_iteration("remove_component", entity)
			var old_archetype = entity_to_archetype[entity]
			var comp_key = component.get_script().get_instance_id()
			var new_archetype = _move_entity_to_new_archetype_fast(
				entity,
				old_archetype,
				comp_key,
				false,
			)
		# Membership changed — bump so cached execute() results know they're stale.
		_bump_membership("entity_component_removed")

	component_removed.emit(entity, component)
	_handle_observer_component_removed(entity, component)
	if (
		not _monitor_entries.is_empty()
		and component != null
		and component.get_script() != null
	):
		_evaluate_monitors_for_entity(entity, component.get_script().resource_path)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
		assert(GECSEditorDebuggerMessages.entity_component_removed(entity, component), "")


## Update index when a relationship is added and move entity to new archetype.
func _on_entity_relationship_added(entity: Entity, relationship: Relationship) -> void:
	# Skip archetype move when called from batch handler re-emitting per-entity signals
	if not _in_batch_relationship_emit:
		# STRUCTURAL: Move entity to new archetype including the pair slot key
		if entity_to_archetype.has(entity):
			if _defer_archetype_moves:
				_queue_deferred_move(entity)
			else:
				if ECS.debug and _iteration_depth > 0:
					_warn_structural_change_during_iteration("add_relationship", entity)
				var old_archetype = entity_to_archetype[entity]
				var slot_key = _relationship_slot_key(relationship)
				if slot_key != "":
					_move_entity_to_new_archetype_fast(entity, old_archetype, slot_key, true)
			_bump_membership("entity_relationship_added")

	relationship_added.emit(entity, relationship)
	_dispatch_observer_event(Observer.Event.RELATIONSHIP_ADDED, entity, relationship)
	if not _monitor_entries.is_empty():
		var rel_path_added = _get_relationship_relation_path(relationship)
		if rel_path_added != "":
			_evaluate_monitors_for_entity(entity, rel_path_added)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
		assert(GECSEditorDebuggerMessages.entity_relationship_added(entity, relationship), "")


## Update index when a relationship is removed and move entity to archetype without the pair slot key.
func _on_entity_relationship_removed(entity: Entity, relationship: Relationship) -> void:
	# Dispatch observer RELATIONSHIP_REMOVED BEFORE archetype move so the entity still
	# structurally satisfies match() queries that reference the relationship type.
	_dispatch_observer_event(Observer.Event.RELATIONSHIP_REMOVED, entity, relationship)
	if not _monitor_entries.is_empty():
		var rel_path_removed = _get_relationship_relation_path(relationship)
		if rel_path_removed != "":
			_evaluate_monitors_for_entity(entity, rel_path_removed)
	# Skip archetype move when called from batch handler re-emitting per-entity signals
	if not _in_batch_relationship_emit:
		# STRUCTURAL: Move entity to archetype without the pair slot key
		if entity_to_archetype.has(entity):
			if _defer_archetype_moves:
				_queue_deferred_move(entity)
			else:
				if ECS.debug and _iteration_depth > 0:
					_warn_structural_change_during_iteration("remove_relationship", entity)
				var old_archetype = entity_to_archetype[entity]
				var slot_key = _relationship_slot_key(relationship)
				if slot_key != "":
					_move_entity_to_new_archetype_fast(entity, old_archetype, slot_key, false)
			_bump_membership("entity_relationship_removed")

	relationship_removed.emit(entity, relationship)
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.lifecycle_active:
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

	# Wire world reference — observer's `q` property is a getter that returns a fresh
	# QueryBuilder on every access (mirrors System.q), so we don't assign it directly.
	_observer._world = self

	# Call user setup() after world/query are wired up
	_observer.setup()

	# Build dispatch entries for this observer from query() + sub_observers()
	_register_observer_entries(_observer)


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
	# Drain any MANUAL-mode pending commands before teardown — otherwise they'd be silently
	# dropped when the observer is freed. Safe to flush with the observer still registered
	# the lambdas do their own is_instance_valid guards.
	if is_instance_valid(observer) and observer.has_pending_commands():
		observer.cmd.execute()
	observers.erase(observer)
	# if ECS.debug:
	# 	# Don't use system_removed as it expects a System not ReactiveSystem
	# 	GECSEditorDebuggerMessages.exit_world()  # Just send a general update
	_unregister_observer_entries(observer)
	observer.queue_free()


## Handle component property changes and notify observers
## [param entity] The entity with the component change
## [param component] The component that changed
## [param property] The property name that changed
## [param new_value] The new value of the property
## [param old_value] The previous value of the property
func handle_component_changed(
	entity: Entity,
	component: Resource,
	property: String,
	new_value: Variant,
	old_value: Variant,
) -> void:
	# Emit the general signal
	component_changed.emit(entity, component, property, new_value, old_value)

	# Find observers watching for this component and notify them
	_handle_observer_component_changed(entity, component, property, new_value, old_value)


## Thin wrapper: routes component-added events through the unified observer dispatch pipeline.
func _handle_observer_component_added(entity: Entity, component: Resource) -> void:
	_dispatch_observer_event(Observer.Event.ADDED, entity, component)


## Thin wrapper: routes component-removed events through the unified observer dispatch pipeline.
func _handle_observer_component_removed(entity: Entity, component: Resource) -> void:
	_dispatch_observer_event(Observer.Event.REMOVED, entity, component)


## Thin wrapper: routes component-changed events through the unified observer dispatch pipeline.
func _handle_observer_component_changed(
	entity: Entity,
	component: Resource,
	property: String,
	new_value: Variant,
	old_value: Variant,
) -> void:
	# Skip the payload Dictionary allocation entirely when nothing subscribes to
	# CHANGED — this runs on EVERY emitting property write.
	var entries: Array = _obs_entries_by_event.get(Observer.Event.CHANGED, [])
	if entries.is_empty():
		return
	var payload: Dictionary = {
		"component": component,
		"property": property,
		"new_value": new_value,
		"old_value": old_value,
	}
	_dispatch_observer_event(Observer.Event.CHANGED, entity, payload)


#region Observer Registration & Dispatch
## Build and register all dispatch entries for an [Observer]. Called from
## [method add_observer] after [method Observer.setup] returns.
## Creates one entry for the top-level [method Observer.query] plus entries for every
## tuple returned by [method Observer.sub_observers]. Each entry is indexed by the events
## its query declares.
func _register_observer_entries(_observer: Observer) -> void:
	var entries: Array = []

	var top_query: QueryBuilder = _observer.query()

	if top_query != null and top_query.has_observer_events():
		# Watched paths for component ADDED/REMOVED/CHANGED events are the union of
		# with_all/with_any components — adding/removing any of those could change the
		# entity's membership in the query.
		var entry := {
			"observer": _observer,
			"query": top_query,
			"callable": Callable(_observer, "each"),
			"watched_paths": _collect_watched_paths(top_query),
			"is_monitor":
			(
				top_query.has_event(Observer.Event.MATCH)
				or top_query.has_event(Observer.Event.UNMATCH)
			),
			"monitor_sensitivity": top_query._component_sensitivity(),
			"membership": {},  # entity -> true, populated for monitor queries
		}
		entries.append(entry)
	elif top_query != null and OS.has_feature("editor"):
		# User declared query() but forgot to chain any event modifiers (.on_added() etc.).
		# Without events nothing is registered and the observer silently never fires —
		# catch this at editor/dev time with a push_warning.
		var _path: String = (
			_observer.get_script().resource_path if _observer.get_script() else "<unknown>"
		)
		push_warning(
			(
				"%s: Observer.query() returned a QueryBuilder with no event modifiers (.on_added / .on_removed / .on_changed / .on_match / .on_unmatch / .on_relationship_added / .on_relationship_removed / .on_event). This observer will never fire — did you forget to chain an event?"
				% _path
			),
		)

	# sub_observers: each tuple becomes its own virtual entry. Queries carry their own
	# event modifiers; callables receive the same (event, entity, payload) shape as each().
	# Tuple shape: [QueryBuilder, Callable, optional yield_existing_override]
	# The 3rd element lets a specific sub-observer opt in/out of yield_existing independently
	# of the parent Observer's flag.
	var subs: Array = _observer.sub_observers()
	for tuple in subs:
		if tuple.size() < 2:
			_worldLogger.warning("sub_observers tuple must be [QueryBuilder, Callable]: ", tuple)
			continue
		if not (tuple[0] is QueryBuilder):
			(
				_worldLogger
				.warning(
					"sub_observers tuple[0] must be QueryBuilder, got: ",
					tuple[0],
				)
			)
			continue
		var sub_q: QueryBuilder = tuple[0]
		var sub_callable: Callable = tuple[1] as Callable
		if not sub_callable.is_valid():
			_worldLogger.warning("sub_observers invalid callable: ", tuple)
			continue
		if not sub_q.has_observer_events():
			_worldLogger.warning("sub_observers query declares no events: ", sub_q)
			continue
		var yield_override = null
		if tuple.size() >= 3:
			yield_override = tuple[2]
		(
			entries
			.append(
				{
					"observer": _observer,
					"query": sub_q,
					"callable": sub_callable,
					"watched_paths": _collect_watched_paths(sub_q),
					"is_monitor":
					(
						sub_q.has_event(Observer.Event.MATCH)
						or sub_q.has_event(Observer.Event.UNMATCH)
					),
					"monitor_sensitivity": sub_q._component_sensitivity(),
					"membership": {},
					"yield_existing_override": yield_override,
				},
			)
		)

	_obs_entries_by_observer[_observer] = entries
	var observer_is_live: bool = _observer.active and not _observer.paused
	for entry in entries:
		_index_observer_entry(entry)
		# yield_existing can be overridden per sub-observer tuple (4th tuple element).
		# null override → fall back to the parent observer's yield_existing flag.
		var yield_override = entry.get("yield_existing_override", null)
		var should_yield: bool = (
			yield_override if yield_override != null else _observer.yield_existing
		)
		# Monitor membership is ALWAYS seeded, even when the observer is inactive/paused.
		# This is framework bookkeeping — without it, flipping `active = true` later would
		# leave pre-existing entities out of the membership set permanently, so MATCH/UNMATCH
		# transitions never fire for them. The retroactive MATCH invocation itself is gated
		# on live state inside _seed_monitor_membership.
		if entry.get("is_monitor", false):
			_seed_monitor_membership(entry, should_yield and observer_is_live)
		elif should_yield and observer_is_live:
			# Non-monitor yield_existing pass: only fire retroactive ADDEDs when live.
			_yield_existing_for_entry(entry)


## Union of [code]with_all[/code] + [code]with_any[/code] component script paths. These are
## the components whose add/remove/change events could affect this query's membership.
func _collect_watched_paths(q: QueryBuilder) -> Array[String]:
	var paths: Array[String] = []
	for c in q._all_components:
		if c is Script and c.resource_path != "" and not paths.has(c.resource_path):
			paths.append(c.resource_path)
	for c in q._any_components:
		if c is Script and c.resource_path != "" and not paths.has(c.resource_path):
			paths.append(c.resource_path)
	return paths


func _index_observer_entry(entry: Dictionary) -> void:
	var q: QueryBuilder = entry.query
	if q == null:
		return
	# Index by Observer.Event bit flags.
	# COPY-ON-WRITE: registration swaps in a fresh array instead of appending in
	# place, so _dispatch_observer_event can iterate the current array without
	# duplicating it per event — re-entrant add_observer inside a callback builds
	# a new array and can't mutate the one being iterated.
	for e in [
		Observer.Event.ADDED,
		Observer.Event.REMOVED,
		Observer.Event.CHANGED,
		Observer.Event.MATCH,
		Observer.Event.UNMATCH,
		Observer.Event.RELATIONSHIP_ADDED,
		Observer.Event.RELATIONSHIP_REMOVED,
	]:
		if q.has_event(e):
			var arr: Array = _obs_entries_by_event.get(e, []).duplicate()
			arr.append(entry)
			_obs_entries_by_event[e] = arr
	# Index by custom event StringName (same COW discipline)
	for ev_name in q._observer_event_names:
		var arr2: Array = _obs_entries_by_custom_event.get(ev_name, []).duplicate()
		arr2.append(entry)
		_obs_entries_by_custom_event[ev_name] = arr2
	if entry.get("is_monitor", false):
		var monitors: Array = _monitor_entries.duplicate()
		monitors.append(entry)
		_monitor_entries = monitors


## Remove all dispatch entries belonging to [param _observer] from the event indexes.
func _unregister_observer_entries(_observer: Observer) -> void:
	var entries: Array = _obs_entries_by_observer.get(_observer, [])
	if entries.is_empty():
		_obs_entries_by_observer.erase(_observer)
		return
	for e_key in _obs_entries_by_event.keys():
		var arr: Array = _obs_entries_by_event[e_key]
		var kept: Array = []
		for entry in arr:
			if entry.observer != _observer:
				kept.append(entry)
		_obs_entries_by_event[e_key] = kept
	for ev_name in _obs_entries_by_custom_event.keys():
		var arr2: Array = _obs_entries_by_custom_event[ev_name]
		var kept2: Array = []
		for entry in arr2:
			if entry.observer != _observer:
				kept2.append(entry)
		_obs_entries_by_custom_event[ev_name] = kept2
	var kept_monitors: Array = []
	for entry in _monitor_entries:
		if entry.observer != _observer:
			kept_monitors.append(entry)
	_monitor_entries = kept_monitors
	_obs_entries_by_observer.erase(_observer)


## Unified observer event dispatch. Called by the three legacy `_handle_observer_component_*`
## wrappers and (in later steps) by relationship / monitor / custom-event paths.
## [param event] An [enum Observer.Event] int flag or a [StringName] custom event.
## [param entity] The entity the event concerns.
## [param payload] Event-specific data — see [Observer.each] doc for the shape table.
func _dispatch_observer_event(event: Variant, entity: Entity, payload: Variant) -> void:
	var entries: Array
	if event is StringName:
		entries = _obs_entries_by_custom_event.get(event, [])
	else:
		entries = _obs_entries_by_event.get(event, [])
	if entries.is_empty():
		return
	# No snapshot needed: (un)registration swaps entry arrays copy-on-write, so a
	# re-entrant add_observer/remove_observer inside a callback builds a NEW array
	# and cannot mutate the one we're iterating.
	# Component-lifecycle events (ADDED/REMOVED/CHANGED) are keyed by the specific
	# component that triggered them — we can cheaply reject entries whose watched_paths
	# don't include that component's script path BEFORE running any world query.
	# This avoids stale-cache false negatives by sidestepping the archetype index.
	var is_int_event := not (event is StringName)
	var component_path: String = ""
	if is_int_event:
		if event == Observer.Event.ADDED or event == Observer.Event.REMOVED:
			if payload != null and payload is Resource and payload.get_script() != null:
				component_path = payload.get_script().resource_path
		elif event == Observer.Event.CHANGED:
			if payload is Dictionary and payload.has("component"):
				var comp = payload.component
				if comp != null and comp.get_script() != null:
					component_path = comp.get_script().resource_path
	for entry in entries:
		var obs: Observer = entry.observer
		if obs == null or not is_instance_valid(obs):
			continue
		if not obs.active or obs.paused:
			continue
		# Watched-component filter for lifecycle events
		if component_path != "":
			var watched: Array = entry.get("watched_paths", [])
			if not watched.is_empty() and not watched.has(component_path):
				continue
		# Property filter for CHANGED events (from on_changed([&"prop"]))
		if is_int_event and event == Observer.Event.CHANGED:
			var q_prop: QueryBuilder = entry.query
			if q_prop != null and not q_prop._observer_changed_props.is_empty():
				if payload is Dictionary and payload.has("property"):
					var prop_name := StringName(payload.property)
					if not q_prop._observer_changed_props.has(prop_name):
						continue
		# Relationship-type filter for RELATIONSHIP_ADDED/REMOVED events
		if (
			is_int_event
			and (
				event == Observer.Event.RELATIONSHIP_ADDED
				or event == Observer.Event.RELATIONSHIP_REMOVED
			)
		):
			var q_b: QueryBuilder = entry.query
			if q_b != null and payload is Relationship:
				var type_filter: Array = (
					q_b._observer_rel_add_types
					if event == Observer.Event.RELATIONSHIP_ADDED
					else q_b._observer_rel_remove_types
				)
				if (
					not type_filter.is_empty()
					and not _relationship_matches_types(payload, type_filter)
				):
					continue
		# Entity query filter. For REMOVED / RELATIONSHIP_REMOVED the removed piece has
		# already been dropped from the entity at signal time, so a naive has_component /
		# has_relationship check would always fail even for entities that DID satisfy the
		# filter before removal. Use a "match-before-removal" check that virtually treats
		# the removed piece as still present.
		# For custom (StringName) events with a null entity, skip the filter entirely —
		# emit_event(name, null, data) is a broadcast to every subscriber.
		if not is_int_event and entity == null:
			pass  # broadcast — no entity filter applicable
		elif is_int_event and event == Observer.Event.REMOVED:
			if not _observer_entry_matched_before_component_removal(
				entry, entity, component_path, payload
			):
				continue
		elif is_int_event and event == Observer.Event.RELATIONSHIP_REMOVED:
			var removed_rel_path := ""
			if payload is Relationship:
				removed_rel_path = _get_relationship_relation_path(payload)
			if not _observer_entry_matched_before_relationship_removal(
				entry, entity, removed_rel_path, payload
			):
				continue
		elif not _observer_entry_entity_matches(entry, entity):
			continue
		# Invoke the callable.
		entry.callable.call(event, entity, payload)
		# Flush command buffer if PER_CALLBACK mode
		if (
			obs.has_pending_commands()
			and obs.command_buffer_flush_mode == Observer.FlushMode.PER_CALLBACK
		):
			obs.cmd.execute()


func _observer_entry_entity_matches(entry: Dictionary, entity: Entity) -> bool:
	var q: QueryBuilder = entry.query
	if q == null:
		return true
	# Direct per-entity check instead of world-level _query() — this avoids hitting a
	# stale archetype cache while observer events fire inside a suppressed batch (e.g.
	# during add_entity's _initialize loop). Query matching here mirrors
	# QueryBuilder.matches() for a single entity.
	for c in q._all_components:
		if not entity.has_component(c):
			return false
	if not q._any_components.is_empty():
		var any_ok := false
		for c in q._any_components:
			if entity.has_component(c):
				any_ok = true
				break
		if not any_ok:
			return false
	for c in q._exclude_components:
		if entity.has_component(c):
			return false
	for rel in q._relationships:
		if not entity.has_relationship(rel):
			return false
	for rel in q._exclude_relationships:
		if entity.has_relationship(rel):
			return false
	if not _evaluate_property_queries(q, entity):
		return false
	if not _evaluate_group_enabled_filters(q, entity):
		return false
	return true


## Match-before-removal check for component REMOVED events. Mirrors
## [method _observer_entry_entity_matches] but treats [param removed_path] as still
## present on the entity so observers with a [code]with_all[/code] filter only fire
## REMOVED for entities that satisfied the full filter prior to removal. When
## [param removed_component] is non-null, property queries keyed on [param removed_path]
## are evaluated against the detached instance — preserving the pre-removal state.
func _observer_entry_matched_before_component_removal(
	entry: Dictionary, entity: Entity, removed_path: String, removed_component: Variant = null
) -> bool:
	var q: QueryBuilder = entry.query
	if q == null:
		return true
	for c in q._all_components:
		if c is Script and c.resource_path == removed_path:
			continue
		if not entity.has_component(c):
			return false
	if not q._any_components.is_empty():
		var any_ok := false
		for c in q._any_components:
			if c is Script and c.resource_path == removed_path:
				any_ok = true
				break
			if entity.has_component(c):
				any_ok = true
				break
		if not any_ok:
			return false
	for c in q._exclude_components:
		# If the removed component matches an exclude, the entity DID fail exclusion
		# before removal, so was NOT matching — return false.
		if c is Script and c.resource_path == removed_path:
			return false
		if entity.has_component(c):
			return false
	for rel in q._relationships:
		if not entity.has_relationship(rel):
			return false
	for rel in q._exclude_relationships:
		if entity.has_relationship(rel):
			return false
	if not _evaluate_property_queries(q, entity, removed_path, removed_component):
		return false
	if not _evaluate_group_enabled_filters(q, entity):
		return false
	return true


## Match-before-removal check for relationship REMOVED events. Treats
## [param removed_rel] as still present (by matching against [param removed_rel_path] or
## equality with the removed [Relationship]) when evaluating the query filter.
func _observer_entry_matched_before_relationship_removal(
	entry: Dictionary, entity: Entity, removed_rel_path: String, removed_rel: Relationship
) -> bool:
	var q: QueryBuilder = entry.query
	if q == null:
		return true
	for c in q._all_components:
		if not entity.has_component(c):
			return false
	if not q._any_components.is_empty():
		var any_ok := false
		for c in q._any_components:
			if entity.has_component(c):
				any_ok = true
				break
		if not any_ok:
			return false
	for c in q._exclude_components:
		if entity.has_component(c):
			return false
	for rel in q._relationships:
		# Treat the removed relationship as still present — but only if it actually
		# satisfied the query rel's criteria. For property-query relationships the
		# detached instance is evaluated via Relationship.matches(); if it doesn't
		# satisfy, fall through to has_relationship so another still-present rel
		# can satisfy the query.
		if removed_rel_path != "" and _get_relationship_relation_path(rel) == removed_rel_path:
			if removed_rel != null and rel.matches(removed_rel):
				continue
		if not entity.has_relationship(rel):
			return false
	for rel in q._exclude_relationships:
		# Only treat the removed rel as "still excluded" if it actually matched the
		# exclude query — a low-damage rel being removed shouldn't fail an exclude
		# that's scoped to high-damage.
		if removed_rel_path != "" and _get_relationship_relation_path(rel) == removed_rel_path:
			if removed_rel != null and rel.matches(removed_rel):
				# The entity DID have this excluded relationship before removal.
				return false
		if entity.has_relationship(rel):
			return false
	if not _evaluate_property_queries(q, entity):
		return false
	if not _evaluate_group_enabled_filters(q, entity):
		return false
	return true


## Evaluate property-query filters on a query against an entity. Used by all three
## observer match helpers. When [param skip_path] is non-empty and [param removed_component]
## is non-null, property queries keyed on [param skip_path] are evaluated against the
## detached instance instead of the entity — this lets match-before-removal callers
## check the removed component's pre-removal property state. If [param removed_component]
## is null (or not a Resource), the property check for the skipped path is treated as
## satisfied (fallback for cases where the instance isn't available).
func _evaluate_property_queries(
	q: QueryBuilder, entity: Entity, skip_path: String = "", removed_component: Variant = null
) -> bool:
	if not q._all_components_queries.is_empty():
		for i in range(q._all_components.size()):
			if i >= q._all_components_queries.size():
				break
			var query_dict = q._all_components_queries[i]
			if query_dict.is_empty():
				continue
			var c_type = q._all_components[i]
			if skip_path != "" and c_type is Script and c_type.resource_path == skip_path:
				# Use the detached removed instance when available; otherwise treat as satisfied.
				if removed_component != null and removed_component is Resource:
					if not ComponentQueryMatcher.matches_query(removed_component, query_dict):
						return false
				continue
			var comp = entity.get_component(c_type)
			if comp == null:
				return false
			if not ComponentQueryMatcher.matches_query(comp, query_dict):
				return false
	if not q._any_components_queries.is_empty():
		# Only evaluate when there are actual property queries.
		var has_any_prop_query := false
		for qd in q._any_components_queries:
			if not qd.is_empty():
				has_any_prop_query = true
				break
		if has_any_prop_query:
			var any_prop_ok := false
			for i in range(q._any_components.size()):
				if i >= q._any_components_queries.size():
					break
				var query_dict = q._any_components_queries[i]
				if query_dict.is_empty():
					continue
				var c_type = q._any_components[i]
				if skip_path != "" and c_type is Script and c_type.resource_path == skip_path:
					# Check the detached removed instance if available; fall back to "satisfied".
					if removed_component != null and removed_component is Resource:
						if ComponentQueryMatcher.matches_query(removed_component, query_dict):
							any_prop_ok = true
							break
					else:
						any_prop_ok = true
						break
					continue
				var comp = entity.get_component(c_type)
				if comp != null and ComponentQueryMatcher.matches_query(comp, query_dict):
					any_prop_ok = true
					break
			if not any_prop_ok:
				return false
	return true


## Evaluate group and enabled/disabled filters on a query against an entity.
## Mirrors the group/enabled semantics in [method QueryBuilder.execute]. These were
## silently ignored by observer dispatch prior to v8.0.0.
func _evaluate_group_enabled_filters(q: QueryBuilder, entity: Entity) -> bool:
	if not q._groups.is_empty():
		for g in q._groups:
			if not entity.is_in_group(g):
				return false
	if not q._exclude_groups.is_empty():
		for g in q._exclude_groups:
			if entity.is_in_group(g):
				return false
	if q._enabled_filter != null and entity.enabled != q._enabled_filter:
		return false
	return true


## True if [param relationship]'s relation component script path matches any entry in
## [param type_filter]. Accepts both Script references and component instances — any
## entry whose resolved resource_path matches the relation's script path counts.
func _relationship_matches_types(relationship: Relationship, type_filter: Array) -> bool:
	var rel_path = _get_relationship_relation_path(relationship)
	if rel_path == "":
		return false
	for t in type_filter:
		var p: String = ""
		if t is Script:
			p = t.resource_path
		elif t is Resource and t.get_script() != null:
			p = t.get_script().resource_path
		if p != "" and p == rel_path:
			return true
	return false


## yield_existing pass for non-monitor observers: fire ADDED for every pre-existing
## component instance on entities that currently satisfy the entry's entity filter.
## Only fires events the entry's query declared (e.g. skipped if only .on_changed()).
func _yield_existing_for_entry(entry: Dictionary) -> void:
	var q: QueryBuilder = entry.query
	if q == null:
		return
	var obs: Observer = entry.observer
	if obs == null or not is_instance_valid(obs) or not obs.active or obs.paused:
		return
	var fires_added: bool = q.has_event(Observer.Event.ADDED)
	if not fires_added:
		return
	var watched: Array = entry.get("watched_paths", [])
	# Snapshot entities and components: a user callback invoked via _invoke_entry may
	# mutate either list (remove_entity, remove_component, etc). Iterating the live
	# arrays would skip or crash; duplicate so iteration is stable.
	for entity in entities.duplicate():
		if not is_instance_valid(entity):
			continue
		if not _observer_entry_entity_matches(entry, entity):
			continue
		# Re-check active between iterations in case a callback flips it.
		if not obs.active or obs.paused:
			return
		for comp in entity.components.values().duplicate():
			if not is_instance_valid(comp) or comp.get_script() == null:
				continue
			var cp: String = comp.get_script().resource_path
			if watched.is_empty() or watched.has(cp):
				_invoke_entry(entry, Observer.Event.ADDED, entity, comp)


## When an entity is removed from the world, evict it from all monitor membership sets
## and fire UNMATCH on monitors that had it.
func _drop_entity_from_monitors(entity: Entity) -> void:
	if _monitor_entries.is_empty():
		return
	# _monitor_entries is maintained copy-on-write and already deduped —
	# callbacks mutating observer registration swap in a new array, so
	# iterating the current reference stays safe.
	for entry in _monitor_entries:
		if entry.membership.has(entity):
			entry.membership.erase(entity)
			var q: QueryBuilder = entry.query
			if q != null and q.has_event(Observer.Event.UNMATCH):
				var obs: Observer = entry.observer
				if obs != null and is_instance_valid(obs) and obs.active and not obs.paused:
					_invoke_entry(entry, Observer.Event.UNMATCH, entity, null)


## Populate a monitor entry's membership set with entities currently matching its query.
## If the observer has [code]yield_existing[/code], also fires MATCH for each seeded entity.
func _seed_monitor_membership(entry: Dictionary, yield_existing: bool = false) -> void:
	var q: QueryBuilder = entry.query
	var obs: Observer = entry.observer
	if q == null or obs == null or not is_instance_valid(obs):
		return
	# Walk existing entities (can't rely on query.execute() for monitor-only queries
	# that declared only on_event; but for MATCH we need the query's structural filters).
	# Membership population is framework bookkeeping and happens even when the observer
	# is inactive/paused — see §1.4 fix. The retroactive MATCH fire is gated on
	# active/paused. [param yield_existing] resolves parent-observer vs per-tuple
	# override at the caller.
	# Snapshot entities: a MATCH callback may mutate the world's entities array.
	for entity in entities.duplicate():
		if not is_instance_valid(entity):
			continue
		if _observer_entry_entity_matches(entry, entity):
			entry.membership[entity] = true
			if (
				yield_existing
				and q.has_event(Observer.Event.MATCH)
				and obs.active
				and not obs.paused
			):
				_invoke_entry(entry, Observer.Event.MATCH, entity, null)


## Re-evaluate monitor-mode observers whose sensitivity set intersects [param touched_paths].
## Fires MATCH / UNMATCH on membership delta for [param entity].
## Evaluate monitor (on_match/on_unmatch) transitions for one entity after a
## structural or property event touched [param touched_path] (a component
## script resource_path; "" = evaluate regardless of sensitivity).
## Zero-allocation: iterates the prebuilt COW _monitor_entries list and
## early-outs when no monitors are registered — the common case.
func _evaluate_monitors_for_entity(entity: Entity, touched_path: String = "") -> void:
	if _monitor_entries.is_empty():
		return
	if entity == null or not is_instance_valid(entity):
		return
	for entry in _monitor_entries:
		var obs: Observer = entry.observer
		if obs == null or not is_instance_valid(obs) or not obs.active or obs.paused:
			continue
		# Cheap rejection by sensitivity
		if touched_path != "":
			var sens: Array = entry.get("monitor_sensitivity", [])
			if not sens.is_empty() and not sens.has(touched_path):
				continue
		var was_matching: bool = entry.membership.has(entity)
		var now_matches: bool = _observer_entry_entity_matches(entry, entity)
		if now_matches and not was_matching:
			entry.membership[entity] = true
			var q: QueryBuilder = entry.query
			if q != null and q.has_event(Observer.Event.MATCH):
				_invoke_entry(entry, Observer.Event.MATCH, entity, null)
		elif was_matching and not now_matches:
			entry.membership.erase(entity)
			var q2: QueryBuilder = entry.query
			if q2 != null and q2.has_event(Observer.Event.UNMATCH):
				_invoke_entry(entry, Observer.Event.UNMATCH, entity, null)


## Invoke the callable on an observer entry with the standard (event, entity, payload)
## shape, flushing [member Observer.cmd] per the observer's flush mode. The callable
## validity check is defensive — protects against observers queue-freed mid-dispatch.
func _invoke_entry(entry: Dictionary, event: Variant, entity: Entity, payload: Variant) -> void:
	var obs: Observer = entry.observer
	var c: Callable = entry.callable
	if c.is_valid():
		c.call(event, entity, payload)
	if (
		obs.has_pending_commands()
		and obs.command_buffer_flush_mode == Observer.FlushMode.PER_CALLBACK
	):
		obs.cmd.execute()


## Emit a custom observer event. Observers whose [QueryBuilder] declared
## [code].on_event(event_name)[/code] will receive this event through their [method Observer.each]
## callback (dispatch respects the observer's entity filter via [method QueryBuilder.match]).[br]
## [param event_name] Name of the event (use [StringName] literals like [code]&"damage_dealt"[/code]).[br]
## [param entity] The [Entity] the event concerns; passed through to observer callbacks.[br]
## [param data] Arbitrary user payload delivered to observers as the third argument.[br]
## [b]Example:[/b]
## [codeblock]
## ECS.world.emit_event(&"damage_dealt", target, {"amount": 10, "source": attacker})
## [/codeblock]
func emit_event(event_name: StringName, entity: Entity = null, data: Variant = null) -> void:
	# null entity is explicitly permitted for custom events — broadcasts to every
	# subscriber regardless of entity filter (the filter can't be evaluated without
	# an entity). Filtered int events still require a valid entity.
	if entity != null and not is_instance_valid(entity):
		return
	_dispatch_observer_event(event_name, entity, data)


#endregion Observer Registration & Dispatch

#endregion Signal Callbacks

#endregion Public Methods

#region Utility Methods


func _query(
	all_components = [],
	any_components = [],
	exclude_components = [],
	enabled_filter = null,
	precalculated_cache_key: int = -1,
	rel_slot_keys: Array = [],
	wildcard_rel_types: Array = [],
	ex_rel_slot_keys: Array = [],
	wildcard_ex_rel_types: Array = [],
) -> Array:
	# Opt-in query timing; off unless perf tooling enabled it (see perf_instrumentation).
	# Explicit bool: Godot 4.6 cannot infer types through the ECS autoload
	# reference while this script parses inside the ecs.gd dependency cycle.
	var _perf: bool = ECS.debug and perf_instrumentation
	var _perf_start_total := 0
	if _perf:
		_perf_start_total = Time.get_ticks_usec()
	# Early return if no components and no structural relationships specified - return all entities
	if (
		all_components.is_empty()
		and any_components.is_empty()
		and exclude_components.is_empty()
		and rel_slot_keys.is_empty()
		and wildcard_rel_types.is_empty()
		and ex_rel_slot_keys.is_empty()
		and wildcard_ex_rel_types.is_empty()
	):
		if enabled_filter == null:
			if _perf:
				perf_mark(
					"query_all_entities",
					Time.get_ticks_usec() - _perf_start_total,
					{"returned": entities.size()},
				)
			return entities
		else:
			# OPTIMIZATION: Use bitset filtering from all archetypes instead of entity.enabled check
			var filtered: Array[Entity] = []
			for archetype in archetypes.values():
				filtered.append_array(archetype.get_entities_by_enabled_state(enabled_filter))
			if _perf:
				perf_mark(
					"query_all_entities_filtered",
					Time.get_ticks_usec() - _perf_start_total,
					{"returned": filtered.size(), "enabled_filter": enabled_filter},
				)
			return filtered

	# OPTIMIZATION: Use pre-calculated cache key if provided (avoids hash recalculation)
	var _perf_start_cache_key := 0
	if _perf:
		_perf_start_cache_key = Time.get_ticks_usec()
	var cache_key = (
		precalculated_cache_key
		if precalculated_cache_key != -1
		else QueryCacheKey.build(all_components, any_components, exclude_components)
	)
	if _perf:
		perf_mark("query_cache_key", Time.get_ticks_usec() - _perf_start_cache_key)

	# Check if we have cached matching archetypes for this query
	var matching_archetypes: Array[Archetype] = []
	if _query_archetype_cache.has(cache_key):
		_cache_hits += 1
		matching_archetypes = _query_archetype_cache[cache_key]
		if _perf:
			perf_mark("query_cache_hit", 0, {"archetypes": matching_archetypes.size()})
	else:
		_cache_misses += 1
		var _perf_start_scan := 0
		if _perf:
			_perf_start_scan = Time.get_ticks_usec()
		# Find all archetypes that match this query
		var map_to_key = func(x): return x.get_instance_id()
		var _all := all_components.map(map_to_key)
		var _any := any_components.map(map_to_key)
		var _exclude := exclude_components.map(map_to_key)

		# Determine candidate archetypes: use wildcard index if available
		var candidates: Array = []
		if not wildcard_rel_types.is_empty():
			# Narrow candidates using _relation_type_archetype_index intersection
			candidates = _get_archetypes_with_all_relation_types(wildcard_rel_types)
		else:
			candidates = archetypes.values()
		var has_structural_rels := (
			not rel_slot_keys.is_empty()
			or not ex_rel_slot_keys.is_empty()
			or not wildcard_ex_rel_types.is_empty()
		)
		for archetype in candidates:
			if archetype.matches_query(_all, _any, _exclude):
				if has_structural_rels:
					if not archetype.matches_relationship_query(rel_slot_keys, ex_rel_slot_keys):
						continue
					# Check wildcard exclusion: archetype must not have any of the excluded rel types
					if (
						not wildcard_ex_rel_types.is_empty()
						and _archetype_has_any_relation_type(archetype, wildcard_ex_rel_types)
					):
						continue
				matching_archetypes.append(archetype)
		# Cache the matching archetypes (not the entity arrays!) plus the match
		# terms so _register_new_archetype can maintain this entry incrementally.
		_query_archetype_cache[cache_key] = matching_archetypes
		_query_cache_terms[cache_key] = [
			_all,
			_any,
			_exclude,
			rel_slot_keys.duplicate(),
			ex_rel_slot_keys.duplicate(),
			wildcard_rel_types.duplicate(),
			wildcard_ex_rel_types.duplicate(),
		]
		if _perf:
			perf_mark(
				"query_archetype_scan",
				Time.get_ticks_usec() - _perf_start_scan,
				{"archetypes": matching_archetypes.size()},
			)

	# OPTIMIZATION: If there's only ONE matching archetype with no filtering, return it directly
	# This avoids array allocation and copying for the common case
	if matching_archetypes.size() == 1 and enabled_filter == null:
		if _perf:
			perf_mark(
				"query_single_archetype",
				Time.get_ticks_usec() - _perf_start_total,
				{"entities": matching_archetypes[0].entities.size()},
			)
		return matching_archetypes[0].entities

	# Collect entities from all matching archetypes with enabled filtering if needed
	var _perf_start_flatten := 0
	if _perf:
		_perf_start_flatten = Time.get_ticks_usec()
	var result: Array[Entity] = []
	for archetype in matching_archetypes:
		if enabled_filter == null:
			# No filtering - add all entities
			result.append_array(archetype.entities)
		else:
			# OPTIMIZATION: Use bitset filtering instead of per-entity enabled check
			result.append_array(archetype.get_entities_by_enabled_state(enabled_filter))
	if _perf:
		perf_mark(
			"query_flatten",
			Time.get_ticks_usec() - _perf_start_flatten,
			{"returned": result.size(), "archetypes": matching_archetypes.size()},
		)
		perf_mark(
			"query_total",
			Time.get_ticks_usec() - _perf_start_total,
			{"returned": result.size()},
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
##         var velocities = archetype.get_column(C_Velocity.get_instance_id())
##         for i in range(velocities.size()):
##             # Process with cache-friendly column access
## [/codeblock]
func get_matching_archetypes(query_builder: QueryBuilder) -> Array[Archetype]:
	# Opt-in query timing; off unless perf tooling enabled it (see perf_instrumentation).
	# Explicit bool: Godot 4.6 cannot infer types through the ECS autoload
	# reference while this script parses inside the ecs.gd dependency cycle.
	var _perf: bool = ECS.debug and perf_instrumentation
	var _perf_start := 0
	if _perf:
		_perf_start = Time.get_ticks_usec()
	var all_components = query_builder._all_components
	var any_components = query_builder._any_components
	var exclude_components = query_builder._exclude_components

	# Extract structural relationship info from query builder
	var rel_slot_keys = query_builder._structural_rel_keys
	var wildcard_rel_types = query_builder._wildcard_rel_types
	var ex_rel_slot_keys = query_builder._structural_ex_rel_keys
	var wildcard_ex_rel_types = query_builder._wildcard_ex_rel_types

	# Use the relationship-aware cache key from query builder
	var cache_key = query_builder.get_cache_key()

	if _query_archetype_cache.has(cache_key):
		if _perf:
			perf_mark("archetypes_cache_hit", Time.get_ticks_usec() - _perf_start)
		return _query_archetype_cache[cache_key]

	var map_to_key = func(x): return x.get_instance_id()
	var _all := all_components.map(map_to_key)
	var _any := any_components.map(map_to_key)
	var _exclude := exclude_components.map(map_to_key)

	var matching: Array[Archetype] = []
	var _perf_scan_start := 0
	if _perf:
		_perf_scan_start = Time.get_ticks_usec()
	# Determine candidate archetypes: use wildcard index if available
	var candidates: Array = []
	if not wildcard_rel_types.is_empty():
		candidates = _get_archetypes_with_all_relation_types(wildcard_rel_types)
	else:
		candidates = archetypes.values()
	var has_structural_rels := (
		not rel_slot_keys.is_empty()
		or not ex_rel_slot_keys.is_empty()
		or not wildcard_ex_rel_types.is_empty()
	)
	for archetype in candidates:
		if archetype.matches_query(_all, _any, _exclude):
			if has_structural_rels:
				if not archetype.matches_relationship_query(rel_slot_keys, ex_rel_slot_keys):
					continue
				if (
					not wildcard_ex_rel_types.is_empty()
					and _archetype_has_any_relation_type(archetype, wildcard_ex_rel_types)
				):
					continue
			matching.append(archetype)
	if _perf:
		perf_mark(
			"archetypes_scan",
			Time.get_ticks_usec() - _perf_scan_start,
			{"archetypes": matching.size()},
		)

	_query_archetype_cache[cache_key] = matching
	_query_cache_terms[cache_key] = [
		_all,
		_any,
		_exclude,
		rel_slot_keys.duplicate(),
		ex_rel_slot_keys.duplicate(),
		wildcard_rel_types.duplicate(),
		wildcard_ex_rel_types.duplicate(),
	]
	if _perf:
		perf_mark(
			"archetypes_total",
			Time.get_ticks_usec() - _perf_start,
			{"archetypes": matching.size()},
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
		"invalidation_reasons": _cache_invalidation_reasons.duplicate(),
	}


## Reset cache statistics
func reset_cache_stats() -> void:
	_cache_hits = 0
	_cache_misses = 0
	_cache_invalidation_count = 0
	_cache_invalidation_reasons.clear()


## Membership bump — the CHEAP invalidation tier, fired on every structural change.
## Records that entity↔archetype membership changed so QueryBuilder entity-array
## caches (execute() results) detect staleness via [member cache_version].
## Does NOT clear _query_archetype_cache: an entity moving between EXISTING
## archetypes can never change which archetypes match a query — only archetype
## creation/deletion can, and those maintain the cache incrementally
## (_register_new_archetype / _delete_archetype).
## Still emits [signal cache_invalidated] for external listeners (a no-listener
## emit is ~free now that world.query no longer auto-connects every builder).
func _bump_membership(reason: String) -> void:
	# Coalesce during batch operations; _end_suppress fires one bump at the end.
	if _suppress_invalidation_depth > 0:
		_pending_invalidation = true
		return

	_pending_invalidation = false
	cache_version += 1
	cache_invalidated.emit()

	_cache_invalidation_count += 1
	_cache_invalidation_reasons[reason] = _cache_invalidation_reasons.get(reason, 0) + 1


## Full invalidation — the RARE tier. Clears the query→archetype cache wholesale.
## Only for events that rebuild the archetype set entirely (purge, compact).
func _invalidate_cache_full(reason: String) -> void:
	_pending_invalidation = false
	_query_archetype_cache.clear()
	_query_cache_terms.clear()
	cache_version += 1
	archetype_set_version += 1
	cache_invalidated.emit()

	_cache_invalidation_count += 1
	_cache_invalidation_reasons[reason] = _cache_invalidation_reasons.get(reason, 0) + 1


## Deprecated alias kept for external callers — full clear.
func _invalidate_cache(reason: String) -> void:
	_invalidate_cache_full(reason)


## Allocate a fresh generational handle: low 32 bits = slot index + 1, high 32
## bits = that slot's current generation. Recycled slots have a bumped generation
## so a stale handle can never alias a new entity. The +1 bias keeps handle 0
## reserved as the "unassigned" sentinel (slot 0 at generation 0 would otherwise
## produce id == 0, breaking the `entity.id == 0` allocation check).
func _alloc_entity_id() -> int:
	var index: int
	if _free_slots.is_empty():
		index = _slot_generations.size()
		_slot_generations.append(0)
	else:
		index = _free_slots.pop_back()
	return (index + 1) | (_slot_generations[index] << 32)


## Release a locally-allocated handle: bump the slot generation and recycle the
## index. No-ops for foreign (pre-assigned) ids whose slot/generation don't match.
func _free_entity_id(id: int) -> void:
	var index := (id & 0xFFFFFFFF) - 1
	if (
		index >= 0
		and index < _slot_generations.size()
		and ((index + 1) | (_slot_generations[index] << 32)) == id
	):
		_slot_generations[index] += 1
		_free_slots.append(index)


## Reserve slot indices below [param base_index] so locally-allocated handles
## never collide with an authority's (FLECS-style entity ranges). Call on
## network clients before spawning local-only entities; replicated entities
## keep the server-assigned id verbatim.
func set_entity_range(base_index: int) -> void:
	if _slot_generations.size() < base_index:
		_slot_generations.resize(base_index)  # zero-filled; never enters _free_slots


## CHANGE DETECTION: start tracking write versions for a component key.
## Called lazily the first time a query declares .changed([C_X]); retrofits
## version columns onto every existing archetype holding that component.
func _register_change_tracking(comp_key: int) -> void:
	if _change_tracked_keys.has(comp_key):
		return
	_change_tracked_keys[comp_key] = true
	for archetype in archetypes.values():
		archetype.ensure_change_tracking(comp_key)


## CHANGE DETECTION: stamp an entity's row for [param component] with the
## current write tick. Called from the property-change path for setter-emitting
## components, and from Entity.mark_changed for components mutated directly.
func _mark_component_changed(entity: Entity, component: Resource) -> void:
	var archetype = entity_to_archetype.get(entity)
	if archetype == null:
		return
	var comp_key: int = component.get_script().get_instance_id()
	if _change_tracked_keys.has(comp_key):
		archetype.mark_changed(comp_key, entity)


## Ensure an entity has an id, allocating a handle if needed. Used for
## relationship targets referenced before they're added to the world.
func _ensure_entity_id(entity: Entity) -> int:
	if entity == null:
		return 0
	if entity.id == 0:
		entity.id = _alloc_entity_id()
	return entity.id


func _get_relationship_relation_path(relationship: Relationship) -> String:
	if relationship == null or relationship.relation == null:
		return ""
	var rel_script = relationship.relation.get_script()
	if rel_script:
		return rel_script.resource_path
	return relationship.relation.resource_path


## Begin a batch suppression window — increments depth counter.
func _begin_suppress() -> void:
	_suppress_invalidation_depth += 1


## End a batch suppression window — decrements depth counter and fires the deferred membership bump if pending.
func _end_suppress() -> void:
	_suppress_invalidation_depth -= 1
	if _suppress_invalidation_depth == 0 and _pending_invalidation:
		_bump_membership("deferred_pending")


## Open a deferred-move window: structural handlers queue touched entities instead
## of moving them between archetypes per operation. Returns true if this call opened
## the window (the caller then owns closing it via _end_deferred_moves); false if a
## window was already open (nested CommandBuffer.execute during observer flush).
func _begin_deferred_moves() -> bool:
	if _defer_archetype_moves:
		return false
	_defer_archetype_moves = true
	return true


## Close the deferred-move window and commit ONE archetype transition per touched
## entity (final signature computed once from the entity's current state).
func _end_deferred_moves() -> void:
	_defer_archetype_moves = false
	for entity in _deferred_move_entities:
		if is_instance_valid(entity) and _deferred_move_set.has(entity):
			_commit_move(entity)
	_deferred_move_entities.clear()
	_deferred_move_set.clear()


## Record an entity as needing an archetype move when the deferred window closes.
func _queue_deferred_move(entity: Entity) -> void:
	if not _deferred_move_set.has(entity):
		_deferred_move_set[entity] = true
		_deferred_move_entities.append(entity)


## Commit one entity's pending deferred move immediately — used before entity
## add/remove ops inside a command flush so they see consistent archetype state.
## No-op if the entity has no pending move.
func _commit_deferred_move(entity: Entity) -> void:
	if _deferred_move_set.has(entity):
		_deferred_move_set.erase(entity)
		_deferred_move_entities.erase(entity)
		_commit_move(entity)


## Move an entity to the archetype matching its CURRENT components/relationships —
## one signature calc, one transition. Shared by deferred-move commits and the
## batch paths in Entity.add_components/remove_components.
func _commit_move(entity: Entity) -> void:
	if not entity_to_archetype.has(entity):
		return
	var old_archetype: Archetype = entity_to_archetype[entity]
	var new_signature = _calculate_entity_signature(entity)
	var comp_types = _get_entity_archetype_keys(entity)
	var new_archetype = _get_or_create_archetype(new_signature, comp_types)
	if new_archetype == old_archetype:
		# Same archetype — refresh column data in case component instances were
		# replaced (add_component over an existing key) during the batch.
		var entity_index = old_archetype.entity_to_index[entity]
		for comp_key in entity.components:
			if old_archetype.columns.has(comp_key):
				old_archetype.columns[comp_key][entity_index] = entity.components[comp_key]
		return
	old_archetype.remove_entity(entity)
	new_archetype.add_entity(entity)
	entity_to_archetype[entity] = new_archetype
	# Empty old archetype is kept — see _remove_entity_from_archetype.


## Recompute this entity's archetype now — or queue it if a deferred-move window
## is open. Entry point for Entity.add_components/remove_components batches.
func _refresh_entity_archetype(entity: Entity) -> void:
	if not entity_to_archetype.has(entity):
		return
	if _defer_archetype_moves:
		_queue_deferred_move(entity)
	else:
		_commit_move(entity)


## Debug-mode aid: flag direct structural mutation while a zero-copy system
## iteration is in progress (swap-remove can skip entities mid-loop). The
## mutation still proceeds — this is guidance, not enforcement.
func _warn_structural_change_during_iteration(what: String, entity: Entity) -> void:
	push_error(
		(
			"GECS: %s on '%s' during zero-copy system iteration. Route structural changes through cmd (CommandBuffer) inside process(), or set safe_iteration = true on the system."
			% [what, entity.name if entity else "<null>"]
		)
	)


## Get the stable handle id of a relationship's target entity.
## Returns 0 if target is not an Entity.
func _get_relationship_target_id(relationship: Relationship) -> int:
	var target = relationship.target
	if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
		return 0  # dangling target; `is` errors on a freed operand
	if target is Entity:
		return _ensure_entity_id(target)
	return 0


## Handle batch relationship additions — single archetype transition for N relationships.
func _on_entity_relationships_batch_added(entity: Entity, _relationships: Array) -> void:
	_begin_suppress()
	var moved := false

	# STRUCTURAL: Single archetype transition using fully-updated signature
	if entity_to_archetype.has(entity):
		if _defer_archetype_moves:
			_queue_deferred_move(entity)
			moved = true
		else:
			var old_archetype = entity_to_archetype[entity]
			var new_signature = _calculate_entity_signature(entity)
			var comp_types = _get_entity_archetype_keys(entity)
			var new_archetype = _get_or_create_archetype(new_signature, comp_types)
			if old_archetype != new_archetype:
				old_archetype.remove_entity(entity)
				new_archetype.add_entity(entity)
				entity_to_archetype[entity] = new_archetype
				moved = true

	_end_suppress()
	# If entity moved to an existing archetype, _end_suppress may not have
	# triggered invalidation (no new archetype → no _pending_invalidation).
	if moved:
		_bump_membership("batch_relationship_added")

	# Emit per-relationship signals on the entity so external listeners
	# (e.g. network_sync) see each change. Guard prevents our own single
	# handler from doing redundant archetype moves.
	_in_batch_relationship_emit = true
	for relationship in _relationships:
		entity.relationship_added.emit(entity, relationship)
	_in_batch_relationship_emit = false


## Handle batch relationship removals — single archetype transition for N relationships.
## Vestigial as of v8.0.0: Entity.remove_relationships now emits per-rel as it goes,
## so this handler is only invoked if external code (e.g. a future network layer)
## emits the relationships_batch_removed signal directly. Kept for API stability.
func _on_entity_relationships_batch_removed(entity: Entity, _relationships: Array) -> void:
	_begin_suppress()
	var moved := false

	# STRUCTURAL: Single archetype transition
	if entity_to_archetype.has(entity):
		if _defer_archetype_moves:
			_queue_deferred_move(entity)
			moved = true
		else:
			var old_archetype = entity_to_archetype[entity]
			var new_signature = _calculate_entity_signature(entity)
			var comp_types = _get_entity_archetype_keys(entity)
			var new_archetype = _get_or_create_archetype(new_signature, comp_types)
			if old_archetype != new_archetype:
				old_archetype.remove_entity(entity)
				new_archetype.add_entity(entity)
				entity_to_archetype[entity] = new_archetype
				moved = true

	_end_suppress()
	if moved:
		_bump_membership("batch_relationship_removed")

	# Emit per-relationship signals on the entity so external listeners
	# (e.g. network_sync) see each change.
	_in_batch_relationship_emit = true
	for relationship in _relationships:
		entity.relationship_removed.emit(entity, relationship)
	_in_batch_relationship_emit = false


## REMOVE policy: Clean up relationships pointing TO a target entity being removed.
## Called inside remove_entity() before the target is freed.
func _cleanup_relationships_to_target(target: Entity) -> void:
	var target_id: int = target.id
	if target_id == 0:
		return

	# Find all entities in archetypes that hold a slot key pointing to this target.
	# Slot key format: "rel://relation_path::entity#<target id>"
	var suffix = "::entity#" + str(target_id)
	var source_entities: Array[Entity] = []

	for rel_path in _relation_type_archetype_index.keys():
		var type_archetypes: Dictionary = _relation_type_archetype_index[rel_path]
		for archetype in type_archetypes.values():
			for rel_key in archetype.relationship_types:
				if rel_key.ends_with(suffix):
					source_entities.append_array(archetype.entities.duplicate())
					break  # found one matching slot in this archetype — all entities match

	if source_entities.is_empty():
		return

	_begin_suppress()

	for source_entity in source_entities:
		if not is_instance_valid(source_entity):
			continue
		var rels_to_remove: Array = []
		for rel in source_entity.relationships:
			var rel_target = rel.target
			if typeof(rel_target) == TYPE_OBJECT and not is_instance_valid(rel_target):
				continue  # dangling target from an earlier direct free; can't match
			if rel_target is Entity and rel_target == target:
				rels_to_remove.append(rel)
		# Go through the documented Entity.remove_relationship API so any future
		# bookkeeping there (beyond erase+emit) stays consistent with other removal paths.
		for rel in rels_to_remove:
			source_entity.remove_relationship(rel)

	_end_suppress()


## Calculate archetype signature for an entity based on its components
## Uses the same hash function as queries for consistency
## An entity signature is just a query with all its components (no any/exclude)
func _calculate_entity_signature(entity: Entity) -> int:
	# Get component keys (script instance ids)
	var comp_keys = entity.components.keys()
	comp_keys.sort()  # Sort keys for consistent ordering

	# Convert keys to Script objects using cached scripts (load once, reuse forever)
	var comp_scripts = []
	for comp_key in comp_keys:
		# Check cache first
		if not _component_script_cache.has(comp_key):
			# Load once and cache
			var component = entity.components[comp_key]
			_component_script_cache[comp_key] = component.get_script()
		comp_scripts.append(_component_script_cache[comp_key])

	# Collect structural relationships for signature hash
	# Property-query relationships are excluded (they remain post-filter only)
	var structural_rels: Array = []
	for rel in entity.relationships:
		if rel._is_query_relationship or _get_relationship_relation_path(rel) == "":
			continue
		# Skip relationships whose Entity target was freed outside remove_entity
		# (e.g. direct queue_free teardown); dangling rels are inert, matching
		# Relationship.valid() semantics, and must not shape the signature.
		var rel_target = rel.target
		if typeof(rel_target) == TYPE_OBJECT and not is_instance_valid(rel_target):
			continue
		structural_rels.append(rel)

	# Use the SAME hash function as queries - entity is just "all components, no any/exclude"
	# OPTIMIZATION: Removed enabled_marker from signature - now handled by bitset in archetype
	var signature = QueryCacheKey.build(comp_scripts, [], [], structural_rels)

	return signature


## Get archetypes that contain ALL specified relation types (wildcard index intersection)
func _get_archetypes_with_all_relation_types(rel_types: Array) -> Array:
	var result = null
	for rel_path in rel_types:
		var type_archetypes = _relation_type_archetype_index.get(rel_path, {})
		if result == null:
			result = type_archetypes.duplicate()
		else:
			for sig in result.keys():
				if not type_archetypes.has(sig):
					result.erase(sig)
	return result.values() if result else []


## Check if archetype has any relationship of the specified types
func _archetype_has_any_relation_type(archetype: Archetype, rel_types: Array) -> bool:
	for rel_path in rel_types:
		if _relation_type_archetype_index.has(rel_path):
			if _relation_type_archetype_index[rel_path].has(archetype.signature):
				return true
	return false


## Compute the archetype slot key string for a relationship pair.
## Format: "rel://<relation_resource_path>::<target_key>"
func _relationship_slot_key(rel: Relationship) -> String:
	var rel_path = _get_relationship_relation_path(rel)
	if rel_path == "":
		return ""
	# Freed targets (Entity freed outside remove_entity) are inert; no slot key,
	# consistent with _calculate_entity_signature skipping dangling rels.
	var target = rel.target
	if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
		return ""
	return _relationship_slot_key_from_parts(rel_path, target)


func _relationship_slot_key_from_parts(rel_path: String, target: Variant) -> String:
	var target_key: String
	if target is Entity:
		target_key = "entity#" + str(_ensure_entity_id(target))
	elif target is Component:
		target_key = "comp://" + target.get_script().resource_path
	elif target is Script:
		target_key = "script://" + target.resource_path
	else:
		target_key = "*"
	return "rel://" + rel_path + "::" + target_key


func _get_compatible_relationship_slot_keys(rel: Relationship) -> Array:
	var rel_path = _get_relationship_relation_path(rel)
	if rel_path == "":
		return []

	var keys: Array = []
	var primary_key = _relationship_slot_key(rel)
	if primary_key != "":
		keys.append(primary_key)

	var rel_target = rel.target
	if typeof(rel_target) == TYPE_OBJECT and not is_instance_valid(rel_target):
		return keys  # dangling target; no compatible slots, matches nothing

	if rel_target is Entity or rel_target is Component:
		var target_script = rel_target.get_script()
		if target_script:
			var script_key = _relationship_slot_key_from_parts(rel_path, target_script)
			if not keys.has(script_key):
				keys.append(script_key)
		var wildcard_key = _relationship_slot_key_from_parts(rel_path, null)
		if not keys.has(wildcard_key):
			keys.append(wildcard_key)

	return keys


## Get the full set of archetype keys for an entity (int component keys + String relationship slot keys)
func _get_entity_archetype_keys(entity: Entity) -> Array:
	var keys = entity.components.keys().duplicate()
	for rel in entity.relationships:
		if not rel._is_query_relationship:
			var slot_key = _relationship_slot_key(rel)
			if slot_key != "":
				keys.append(slot_key)
	return keys


## Extract the relation resource path from a rel:// slot key.
## Input: "rel://res://path/to/component.gd::entity#42"
## Output: "res://path/to/component.gd"
func _extract_relation_path_from_slot_key(slot_key: String) -> String:
	var content = slot_key.substr(6)  # everything after "rel://"
	var sep_pos = content.find("::")
	if sep_pos == -1:
		return ""
	return content.substr(0, sep_pos)


## Get or create an archetype for the given signature and component types
func _get_or_create_archetype(signature: int, component_types: Array) -> Archetype:
	var is_new = not archetypes.has(signature)
	if is_new:
		var archetype = Archetype.new(signature, component_types)
		archetypes[signature] = archetype
		# CHANGE DETECTION: new archetypes get version columns for tracked keys
		if not _change_tracked_keys.is_empty():
			for tracked_key in _change_tracked_keys:
				archetype.ensure_change_tracking(tracked_key)
		_worldLogger.trace("Created new archetype: ", archetype)
		if ECS.debug and not _archetype_explosion_warned and archetypes.size() > 500:
			# Count only non-empty archetypes — empties are retained by design
			# and reclaimable via World.compact().
			var non_empty := 0
			for arch in archetypes.values():
				if not arch.is_empty():
					non_empty += 1
			if non_empty > 500:
				_archetype_explosion_warned = true
				(
					_worldLogger
					.error(
						(
							"Archetype explosion: %d non-empty archetypes (%d total). Each unique (Relation, Target) pair creates a new archetype — check for unintended relationship cardinality. Empty archetypes can be reclaimed with World.compact()."
							% [non_empty, archetypes.size()]
						)
					)
				)

		# Register in wildcard index: for each rel:// key, extract relation path
		for rel_key in archetype.relationship_types:
			var rel_path = _extract_relation_path_from_slot_key(rel_key)
			if rel_path != "":
				if not _relation_type_archetype_index.has(rel_path):
					_relation_type_archetype_index[rel_path] = {}
				_relation_type_archetype_index[rel_path][archetype.signature] = archetype

		# Incrementally maintain cached queries with the new archetype (must run
		# AFTER wildcard-index registration — term matching consults the index).
		_register_new_archetype(archetype)

	return archetypes[signature]


## Incrementally maintain the query→archetype cache when a new archetype appears:
## append it to every cached query whose stored terms it matches. This keeps
## cached queries permanently valid without wholesale invalidation — and it runs
## even inside suppression windows, so mid-batch queries (e.g. observer matching
## during add_entities) see new archetypes immediately.
func _register_new_archetype(archetype: Archetype) -> void:
	archetype_set_version += 1
	var desynced_keys: Array = []
	for cache_key in _query_archetype_cache:
		var terms = _query_cache_terms.get(cache_key)
		if terms == null:
			# Cache entry without stored terms can't be maintained — drop it so it re-misses.
			desynced_keys.append(cache_key)
			continue
		if _archetype_matches_terms(archetype, terms):
			# Copy-on-write: systems may be iterating the cached array THIS frame
			# (direct-mutation style). Appending in place would make their loop
			# visit the new archetype and double-process entities that just moved
			# into it. Swap in a fresh array instead — in-flight holders keep a
			# stable snapshot; the next archetypes() call sees the update.
			var updated: Array[Archetype] = _query_archetype_cache[cache_key].duplicate()
			updated.append(archetype)
			_query_archetype_cache[cache_key] = updated
	for k in desynced_keys:
		_query_archetype_cache.erase(k)
		_query_cache_terms.erase(k)
	_bump_membership("new_archetype_created")


## Test an archetype against stored query terms — the same predicate as the
## cache-miss scan in _query()/get_matching_archetypes().
## terms: [all_ids, any_ids, exclude_ids, rel_slot_keys, ex_rel_slot_keys,
##         wildcard_rel_types, wildcard_ex_rel_types]
func _archetype_matches_terms(archetype: Archetype, terms: Array) -> bool:
	if not archetype.matches_query(terms[0], terms[1], terms[2]):
		return false
	var wildcard_rel_types: Array = terms[5]
	if (
		not wildcard_rel_types.is_empty()
		and not _archetype_has_all_relation_types(archetype, wildcard_rel_types)
	):
		return false
	var rel_slot_keys: Array = terms[3]
	var ex_rel_slot_keys: Array = terms[4]
	var wildcard_ex_rel_types: Array = terms[6]
	if (
		not rel_slot_keys.is_empty()
		or not ex_rel_slot_keys.is_empty()
		or not wildcard_ex_rel_types.is_empty()
	):
		if not archetype.matches_relationship_query(rel_slot_keys, ex_rel_slot_keys):
			return false
		if (
			not wildcard_ex_rel_types.is_empty()
			and _archetype_has_any_relation_type(archetype, wildcard_ex_rel_types)
		):
			return false
	return true


## Check if archetype has ALL of the specified relation types (wildcard match)
func _archetype_has_all_relation_types(archetype: Archetype, rel_types: Array) -> bool:
	for rel_path in rel_types:
		var type_archetypes = _relation_type_archetype_index.get(rel_path)
		if type_archetypes == null or not type_archetypes.has(archetype.signature):
			return false
	return true


## Add entity to appropriate archetype (parallel system)
func _add_entity_to_archetype(entity: Entity) -> void:
	# Calculate signature based on entity's components (enabled state now handled by bitset)
	var signature = _calculate_entity_signature(entity)

	# Get component type paths for this entity (includes relationship slot keys)
	var comp_types = _get_entity_archetype_keys(entity)

	# Get or create archetype (no longer needs enabled filter value)
	var archetype = _get_or_create_archetype(signature, comp_types)

	# Add entity to archetype
	archetype.add_entity(entity)
	entity_to_archetype[entity] = archetype
	# NOTE: No explicit _invalidate_cache here — _get_or_create_archetype already calls
	# _invalidate_cache("new_archetype_created") when a new archetype is created.
	# The outer add_entity() batch (_begin_suppress/_end_suppress) handles the rest.

	_worldLogger.trace("Added entity ", entity.name, " to archetype: ", archetype)


## Remove entity from its current archetype
func _remove_entity_from_archetype(entity: Entity) -> bool:
	if not entity_to_archetype.has(entity):
		return false

	var archetype = entity_to_archetype[entity]
	var removed = archetype.remove_entity(entity)
	entity_to_archetype.erase(entity)

	# Membership changed — QueryBuilder execute() caches must know they're stale
	_bump_membership("entity_removed_from_archetype")

	# Empty archetypes are KEPT (FLECS-style): their transition edges survive
	# spawn/despawn churn, and queries skip them via entities.is_empty().
	# World.compact() reclaims them explicitly.

	return removed


## Delete an archetype from the world, cleaning up reverse edges in all neighbor archetypes.
## Replaces all three inline deletion sites for consistent cleanup.
func _delete_archetype(archetype: Archetype) -> void:
	# Clean up wildcard index entries for this archetype's relationship types
	for rel_key in archetype.relationship_types:
		var rel_path = _extract_relation_path_from_slot_key(rel_key)
		if rel_path != "" and _relation_type_archetype_index.has(rel_path):
			_relation_type_archetype_index[rel_path].erase(archetype.signature)
			if _relation_type_archetype_index[rel_path].is_empty():
				_relation_type_archetype_index.erase(rel_path)

	# Clean incoming edges: iterate neighbors (archetypes that point TO this one)
	# and remove any edge they have pointing to this archetype
	for neighbor in archetype.neighbors.values():
		var keys_to_clear: Array = []
		for comp_path in neighbor.add_edges:
			if neighbor.add_edges[comp_path] == archetype:
				keys_to_clear.append(comp_path)
		for k in keys_to_clear:
			neighbor.add_edges.erase(k)
		keys_to_clear.clear()
		for comp_path in neighbor.remove_edges:
			if neighbor.remove_edges[comp_path] == archetype:
				keys_to_clear.append(comp_path)
		for k in keys_to_clear:
			neighbor.remove_edges.erase(k)

	# Clean outgoing edges: remove this archetype from each target's neighbors
	var my_id := archetype.get_instance_id()
	for target in archetype.add_edges.values():
		target.neighbors.erase(my_id)
	for target in archetype.remove_edges.values():
		target.neighbors.erase(my_id)

	# Incrementally remove from cached query results (deletion is rare, erase is
	# O(n)). Copy-on-write for the same reason as _register_new_archetype: an
	# in-place erase would shift elements under an in-flight iteration.
	for cache_key in _query_archetype_cache:
		var cached: Array[Archetype] = _query_archetype_cache[cache_key]
		var idx := cached.find(archetype)
		if idx != -1:
			var updated: Array[Archetype] = cached.duplicate()
			updated.remove_at(idx)
			_query_archetype_cache[cache_key] = updated
	archetype_set_version += 1

	# Clear own state and remove from world
	archetype.add_edges.clear()
	archetype.remove_edges.clear()
	archetype.neighbors.clear()
	archetypes.erase(archetype.signature)
	_worldLogger.trace("Deleted archetype: ", archetype)


## Fast path: Move entity when we already know which component was added/removed
## This avoids expensive set comparisons to find the difference
## Returns the new archetype the entity was moved to
func _move_entity_to_new_archetype_fast(
	entity: Entity,
	old_archetype: Archetype,
	comp_key: Variant,
	is_add: bool,
) -> Archetype:
	# Try to use archetype edge for O(1) transition
	var new_archetype: Archetype = null

	if is_add:
		# Check if we have a cached edge for this component addition
		new_archetype = old_archetype.get_add_edge(comp_key)
	else:
		# Check if we have a cached edge for this component removal
		new_archetype = old_archetype.get_remove_edge(comp_key)

	# ARCH-01: Guard against stale edge cache references
	# Archetype was deleted when empty — clear edge and fall through to find/create.
	if new_archetype != null and not archetypes.has(new_archetype.signature):
		# Stale edge — archetype was deleted when empty. Clear edge and fall through to find/create.
		if is_add:
			old_archetype.add_edges.erase(comp_key)
		else:
			old_archetype.remove_edges.erase(comp_key)
		new_archetype = null

	# If no cached edge, calculate signature and find/create archetype
	if new_archetype == null:
		var new_signature = _calculate_entity_signature(entity)
		var comp_types = _get_entity_archetype_keys(entity)
		new_archetype = _get_or_create_archetype(new_signature, comp_types)

		# Only cache edges when source and target differ — self-referencing edges
		# arise during _initialize() (clear + re-add same components) and cause
		# subsequent remove_component to "move" the entity back to the same archetype.
		if new_archetype != old_archetype:
			if is_add:
				old_archetype.set_add_edge(comp_key, new_archetype)
				new_archetype.set_remove_edge(comp_key, old_archetype)
			else:
				old_archetype.set_remove_edge(comp_key, new_archetype)
				new_archetype.set_add_edge(comp_key, old_archetype)

	# Skip move if entity is already in the target archetype (e.g. re-add of existing component)
	if new_archetype == old_archetype:
		return old_archetype

	# Remove from old archetype
	old_archetype.remove_entity(entity)

	# Add to new archetype
	new_archetype.add_entity(entity)
	entity_to_archetype[entity] = new_archetype

	_worldLogger.trace("Moved entity ", entity.name, " from ", old_archetype, " to ", new_archetype)

	# Empty old archetype is kept — its edges keep transitions O(1) under churn.

	return new_archetype


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
	elif message == "reset_system_metrics":
		# Editor requested to clear accumulated min/max/avg across all systems.
		for sys in systems:
			sys.reset_performance_metrics()
		return true
	elif message == "poll_entity":
		# Editor requested a component poll for a specific entity
		var entity_id = data[0]
		_poll_entity_for_debugger(entity_id)
		return true
	elif message == "run_entity_query":
		# Editor typed an ad-hoc QueryBuilder expression; evaluate and reply.
		_run_debugger_query(data[0] if data.size() > 0 else "")
		return true
	elif message == "select_entity":
		# Editor requested to select an entity in the scene tree
		var entity_path = data[0]
		# Get the actual node to get its ObjectID
		var node = get_node_or_null(entity_path)
		if node:
			var obj_id = node.get_instance_id()
			var _class_name = node.get_class()

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
						prop_name,
						prop_type,
						prop_hint,
						prop_hint_string,
						prop_usage,
						prop_value,
					]
					properties.append(prop_info)

				# Message format: [object_id, class_name, properties] - only 3 elements!
				var msg_data: Array = [obj_id, _class_name, properties]
				EngineDebugger.send_message("scene:inspect_object", msg_data)
		else:
			push_error("GECS: select_entity could not find node at path: ", entity_path)
		return true
	return false


## Poll a specific entity's components and send updates to the debugger
func _poll_entity_for_debugger(entity_id: int) -> void:
	# Resolve the entity directly by its instance id instead of scanning all entities.
	var obj = instance_from_id(entity_id)
	if not (obj is Entity):
		return
	var entity: Entity = obj
	# Only poll entities this world actually owns.
	if not entity_to_archetype.has(entity):
		return

	# Re-send all component data with fresh serialize() calls, collecting the
	# authoritative id set so the tab can prune components that are already gone.
	var current_comp_ids: Array = []
	for comp_key in entity.components.keys():
		var comp = entity.components[comp_key]
		if comp and comp is Resource:
			current_comp_ids.append(comp.get_instance_id())
			# Send updated component data
			GECSEditorDebuggerMessages.entity_component_added(entity, comp)
	# Reconcile: the tab removes any component rows not in this set. A poll is an
	# editor-initiated pull, so it reflects true state regardless of the lifecycle
	# event category being toggled off.
	GECSEditorDebuggerMessages.entity_components_synced(entity_id, current_comp_ids)


## Evaluate an ad-hoc QueryBuilder expression typed in the debugger tab and reply
## with the matching entity ids. Uses Godot's [Expression] with a fresh [code]q[/code]
## builder plus every global class injected as inputs, so the developer can type real
## query code — e.g. [code]q.with_all([C_A]).with_any([C_B]).with_none([C_C])[/code].
## Editor/dev-only (gated by ECS.debug + editor build). The expression can call methods
## on the injected objects, which is acceptable for a developer inspecting their own game.
func _run_debugger_query(query_text: String) -> void:
	query_text = query_text.strip_edges()
	if query_text == "":
		GECSEditorDebuggerMessages.entity_query_result([], "Empty query")
		return
	# Build the name -> path map once (cheap; no scripts loaded here).
	if _debugger_class_paths.is_empty():
		for entry in ProjectSettings.get_global_class_list():
			var cname: String = entry.get("class", "")
			var cpath: String = entry.get("path", "")
			if cname != "" and cpath != "":
				_debugger_class_paths[cname] = cpath
	# Resolve ONLY the identifiers the query text actually references — avoids
	# loading unrelated (possibly broken or editor-only) global scripts.
	var ident_re := RegEx.new()
	ident_re.compile("[A-Za-z_][A-Za-z0-9_]*")
	var input_names := PackedStringArray(["q"])
	var inputs: Array = [query]
	var seen := {"q": true}
	for m in ident_re.search_all(query_text):
		var ident := m.get_string()
		if seen.has(ident) or not _debugger_class_paths.has(ident):
			continue
		seen[ident] = true
		var scr = _debugger_class_scripts.get(ident, null)
		if scr == null:
			scr = load(_debugger_class_paths[ident])
			if scr != null:
				_debugger_class_scripts[ident] = scr
		if scr != null:
			input_names.append(ident)
			inputs.append(scr)

	var expr := Expression.new()
	var perr := expr.parse(query_text, input_names)
	if perr != OK:
		GECSEditorDebuggerMessages.entity_query_result([], "Parse error: " + expr.get_error_text())
		return
	var result = expr.execute(inputs, null, false)
	if expr.has_execute_failed():
		GECSEditorDebuggerMessages.entity_query_result([], "Eval error: " + expr.get_error_text())
		return
	# Accept either a QueryBuilder (call execute()) or an already-executed Array.
	var entities: Array = []
	if result is QueryBuilder:
		entities = result.execute()
	elif result is Array:
		entities = result
	else:
		GECSEditorDebuggerMessages.entity_query_result(
			[], "Query must return a QueryBuilder or an Array of entities"
		)
		return
	var ids: Array = []
	for e in entities:
		if is_instance_valid(e) and e is Entity:
			ids.append(e.get_instance_id())
	GECSEditorDebuggerMessages.entity_query_result(ids, "")


## Replay the full current world state to a tab that just subscribed. Without this,
## a tab attaching after entities already exist would only ever see entities added
## later (lifecycle events are edge-triggered). Called from ECS._on_debugger_message
## when a subscription enables the lifecycle category.
## NOTE: sends one message per system + per entity + per component/relationship. On a
## very large world this can approach the debugger's queued-message cap
## (project setting network/limits/debugger/max_queued_messages, default 2048);
## Phase 3 can chunk this across frames if that becomes a problem in practice.
func _send_debugger_snapshot() -> void:
	if not (ECS.debug and GECSEditorDebuggerMessages.attached):
		return
	# Re-establish the world context on the freshly-cleared tab.
	assert(GECSEditorDebuggerMessages.world_init(self), "")
	# Systems always accompany a snapshot (the systems panel keys off system_added).
	for system in systems:
		if is_instance_valid(system):
			assert(GECSEditorDebuggerMessages.system_added(system), "")
	# Entity/component/relationship state only when the lifecycle category is on.
	if GECSEditorDebuggerMessages.lifecycle_active:
		for entity in entities:
			if not is_instance_valid(entity):
				continue
			assert(GECSEditorDebuggerMessages.entity_added(entity, entity.is_inside_tree()), "")
			for comp_key in entity.components.keys():
				var comp = entity.components[comp_key]
				if comp and comp is Resource:
					assert(GECSEditorDebuggerMessages.entity_component_added(entity, comp), "")
			for rel in entity.relationships:
				if rel:
					assert(GECSEditorDebuggerMessages.entity_relationship_added(entity, rel), "")

#endregion Debugger Support
