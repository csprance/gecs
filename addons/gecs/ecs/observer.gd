## An [Observer] is a query-driven reactive node. Declare a [QueryBuilder] with event
## modifiers (on_added/on_removed/on_changed/on_match/on_unmatch/on_relationship_added/
## on_relationship_removed/on_event) and the observer fires its [method each] callback
## whenever one of those events occurs on an entity matching the query.
##
## [b]Quick example:[/b]
## [codeblock]
## class_name HealthObserver
## extends Observer
##
## func query() -> QueryBuilder:
##     return q.with_all([C_Health, C_Player]).on_added().on_removed()
##
## func each(event: Variant, entity: Entity, payload: Variant) -> void:
##     match event:
##         Observer.Event.ADDED:   print("Health granted: ", payload)
##         Observer.Event.REMOVED: print("Health lost from: ", entity.name)
## [/codeblock]
##
## [b]Multiple reactive axes — split with [method sub_observers]:[/b]
## [codeblock]
## func sub_observers() -> Array[Array]:
##     return [
##         [q.with_all([C_Health]).on_added(),     _on_join],
##         [q.with_all([C_Health]).on_removed(),   _on_die],
##         [q.with_all([C_Player]).on_event(&"damage_dealt"), _on_damage],
##     ]
## [/codeblock]
##
## [b]Property-change observers:[/b] [method each] fires only when a component explicitly
## emits [signal Component.property_changed]. Setting a property directly does not trigger
## observers. Components that want change events must implement a setter that emits
## [code]property_changed[/code] — this is intentional for performance.
##
## [b]Legacy API note:[/b] the original Observer API ([method watch], [method match],
## [method on_component_added] / [method on_component_removed] / [method on_component_changed])
## remains supported as a shim. New code should prefer [method query] + [method each].
@icon("res://addons/gecs/assets/observer.svg")
class_name Observer
extends Node

#region Enums
## Event types an [Observer]'s [QueryBuilder] can react to. Sequential values — the
## framework derives bit flags internally (via [code]1 << event[/code]) for the
## [member QueryBuilder._observer_events_mask] storage.
enum Event {
	ADDED = 0,                  ## A watched component was added to a matching entity.
	REMOVED = 1,                ## A watched component was removed from a matching entity.
	CHANGED = 2,                ## A watched property changed on a watched component.
	MATCH = 3,                  ## Monitor: entity newly satisfies the query.
	UNMATCH = 4,                ## Monitor: entity no longer satisfies the query.
	RELATIONSHIP_ADDED = 5,     ## A relationship was added to a matching entity.
	RELATIONSHIP_REMOVED = 6,   ## A relationship was removed from a matching entity.
}

## Controls when the observer's [member cmd] [CommandBuffer] executes queued structural changes.
enum FlushMode {
	PER_CALLBACK,    ## Flush after every [method each] invocation (default, safest).
	MANUAL,          ## Flush only when [method World.flush_command_buffers] is called explicitly.
}
#endregion Enums

#region Exported Variables
## If false the observer is skipped entirely (no event callbacks fire).
@export var active: bool = true
## If true, [method each] is fired retroactively at [method setup] time for entities that
## already match the query — useful for observers registered after entities already exist.
@export var yield_existing: bool = false

@export_group("Command Buffer")
## When the queued [member cmd] commands flush.
@export var command_buffer_flush_mode: FlushMode = FlushMode.PER_CALLBACK
#endregion Exported Variables

#region Public Variables
## Is this observer paused. (Will be skipped if true.) Runtime-only — not exported.
var paused: bool = false

## Convenience property that returns a **fresh** [QueryBuilder] on every access.
## Mirrors [member System.q]: each access builds a new builder bound to this observer's
## world, so sub_observers can call [code]q.with_all(...)[/code] independently per tuple
## without them sharing mutable state. If the observer is not yet attached to a world,
## returns the global [code]ECS.world.query[/code] builder or null.
var q: QueryBuilder:
	get:
		return _world.query if _world else (ECS.world.query if ECS.world else null)

## Reference to the [World] this observer belongs to (set by [method World.add_observer]).
var _world: World = null

## Command buffer for queuing structural changes from event callbacks. Lazy — created on first access.
var cmd: CommandBuffer = null:
	get:
		if cmd == null:
			cmd = CommandBuffer.new(_world if _world else ECS.world)
		return cmd

## Logger for observer debugging and tracing.
var observerLogger = GECSLogger.new().domain("Observer")

## Per-frame debug/profile bucket. Populated by the framework when [code]ECS.debug[/code] is true.
var lastRunData := {}
#endregion Public Variables

#region Internal Variables
## Per-query monitor membership. Tracks which entities currently satisfy an
## [code]on_match[/code] / [code]on_unmatch[/code] query for delta detection.
## Framework-managed; do not touch directly.
var _monitor_membership: Dictionary = {}
#endregion Internal Variables


#region Public Methods
## Override to run one-shot initialization after the observer is added to the [World].
## At this point [member _world] and [member q] are valid.
func setup() -> void:
	pass


## Override and return a [QueryBuilder] with event modifiers chained on it
## (e.g. [code]q.with_all([C_Health]).on_added()[/code]) to declare this observer's
## reactive spec. Return [code]null[/code] (the default) to use [method sub_observers]
## exclusively.
func query() -> QueryBuilder:
	return null


## The unified observer callback. Fires for every event declared on [method query].[br]
## [param event] An [enum Observer.Event] value or a [StringName] for custom events.[br]
## [param entity] The [Entity] the event concerns.[br]
## [param payload] Event-type-dependent data; see the payload table in the class doc.
func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	pass


## Override to return a list of sub-observer tuples. Each tuple has the same shape as
## [method System.sub_systems]: [code][QueryBuilder, Callable, optional SystemTimer,
## optional yield_existing_override][/code].
## The callable receives [code](event, entity, payload)[/code] — identical to [method each].[br]
## The 4th element, when non-null, overrides the parent observer's [member yield_existing]
## flag for this tuple only. Pass [code]true[/code] to force retroactive fire for pre-existing
## entities, or [code]false[/code] to suppress it. Leave null (or omit) to inherit the parent.[br]
## [b]Example:[/b]
## [codeblock]
## func sub_observers() -> Array[Array]:
##     return [
##         [q.with_all([C_Health]).on_added(), _on_join],
##         [q.with_all([C_Player, C_Alive]).on_match().on_unmatch(), _on_alive_state],
##         # This sub-observer yields pre-existing entities even when the parent doesn't:
##         [q.with_all([C_Loot]).on_added(), _on_loot, null, true],
##     ]
## [/codeblock]
func sub_observers() -> Array[Array]:
	return []


## Check if this observer has a command buffer with pending commands.
func has_pending_commands() -> bool:
	return cmd != null and not cmd.is_empty()
#endregion Public Methods


#region Legacy API (deprecated shim — do not use in new code)
## [b]Deprecated.[/b] Legacy observer spec returning a single [Component] script class.
## Retained so existing observers keep working; the shim in [method World.add_observer]
## detects a non-null return and synthesizes an equivalent fluent [method query].[br]
## New code should use [method query] + [method each] instead.
func watch() -> Resource:
	return null


## [b]Deprecated.[/b] Legacy entity filter for observers that use [method watch]. Ignored
## when [method query] is overridden.
func match() -> QueryBuilder:
	return q


## [b]Deprecated.[/b] Legacy component-added callback. Only invoked by the legacy shim
## for observers that override [method watch].
func on_component_added(entity: Entity, component: Resource) -> void:
	pass


## [b]Deprecated.[/b] Legacy component-removed callback. Only invoked by the legacy shim.
func on_component_removed(entity: Entity, component: Resource) -> void:
	pass


## [b]Deprecated.[/b] Legacy component-changed callback. Only invoked by the legacy shim.
func on_component_changed(
	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
) -> void:
	pass
#endregion Legacy API
