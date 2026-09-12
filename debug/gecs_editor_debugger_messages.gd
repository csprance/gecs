class_name GECSEditorDebuggerMessages

## A mapping of all the messages sent to the editor debugger.
const Msg = {
	"WORLD_INIT": "gecs:world_init",
	"SYSTEM_METRIC": "gecs:system_metric",
	"SYSTEM_LAST_RUN_DATA": "gecs:system_last_run_data",
	"SET_WORLD": "gecs:set_world",
	"PROCESS_WORLD": "gecs:process_world",
	"EXIT_WORLD": "gecs:exit_world",
	"ENTITY_ADDED": "gecs:entity_added",
	"ENTITY_REMOVED": "gecs:entity_removed",
	"ENTITY_DISABLED": "gecs:entity_disabled",
	"ENTITY_ENABLED": "gecs:entity_enabled",
	"SYSTEM_ADDED": "gecs:system_added",
	"SYSTEM_REMOVED": "gecs:system_removed",
	"ENTITY_COMPONENT_ADDED": "gecs:entity_component_added",
	"ENTITY_COMPONENT_REMOVED": "gecs:entity_component_removed",
	"ENTITY_RELATIONSHIP_ADDED": "gecs:entity_relationship_added",
	"ENTITY_RELATIONSHIP_REMOVED": "gecs:entity_relationship_removed",
	"COMPONENT_PROPERTY_CHANGED": "gecs:component_property_changed",
	"POLL_ENTITY": "gecs:poll_entity",
	"SELECT_ENTITY": "gecs:select_entity",
	# Poll reconciliation: authoritative list of the component ids an entity
	# currently has, so the tab can prune rows for components already removed.
	"ENTITY_COMPONENTS_SYNCED": "gecs:entity_components_synced",
	# Ad-hoc query runner: game -> editor result for a query typed in the tab.
	"ENTITY_QUERY_RESULT": "gecs:entity_query_result",
	# Game -> editor bootstrap: announces the game has GECS so the tab subscribes.
	"READY": "gecs:ready",
	# Step debugger (game -> editor): stepper state, one step log entry, graph payload.
	"STEP_STATE": "gecs:step_state",
	"STEP_LOG": "gecs:step_log",
	"GRAPH_STATE": "gecs:graph_state",
}

## Base capability cache (editor build + live debugger transport): -1 = unresolved,
## 0 = no, 1 = yes. Gates ONLY the bootstrap READY handshake; every richer message
## gates on the subscription flags below.
static var _attached_cache: int = -1

## Master send gate — true only while the editor GECS tab holds an active
## subscription (set by [method apply_subscription], cleared by
## [method clear_subscription]). Call sites read this single static var.
static var attached := false

## Retired push-category flags, kept false for older call sites and integrations.
static var telemetry_active := false
static var lifecycle_active := false
static var property_changes_active := false

## Deprecated compatibility fields; protocol v2 does not stream telemetry.
static var telemetry_interval := 0.1
## No longer used by World.process.
static var telemetry_sample_due := false

## Test seam. When valid, [method _send] routes payloads here instead of the
## engine debugger so headless tests can assert on what would have been sent
## without a live editor session. Left invalid in normal runs.
static var _test_sink := Callable()


## Master gate used inside every sender (and by editor-initiated pulls). True only
## while a subscription is active.
static func can_send_message() -> bool:
	return attached


## Recompute the base transport capability. Cheap runtime checks only: a game build
## with the editor feature AND a live debugger transport. Does NOT flip
## [member attached] — that is driven by the subscription handshake. A valid test
## sink stands in for a fully subscribed session.
static func refresh_attached() -> void:
	if _test_sink.is_valid():
		_attached_cache = 1
		attached = true
		return
	if not Engine.is_editor_hint() and OS.has_feature("editor") and EngineDebugger.is_active():
		_attached_cache = 1
	else:
		_attached_cache = 0


## Cheap check for the ONE message allowed to flow before a subscription exists:
## the READY bootstrap. Uses the base capability, not the subscription flags.
static func _can_bootstrap() -> bool:
	if _attached_cache == -1:
		refresh_attached()
	return _attached_cache == 1


## Attach the Explorer transport. Legacy category/rate arguments are ignored.
static func apply_subscription(_categories: Dictionary = {}, _hz: float = 2.0) -> void:
	# Protocol v2 only attaches the request/response channel.
	telemetry_active = false
	lifecycle_active = false
	property_changes_active = false
	attached = true


## Tear down the subscription (editor unsubscribed or the session stopped).
static func clear_subscription() -> void:
	attached = false
	telemetry_active = false
	lifecycle_active = false
	property_changes_active = false
	telemetry_sample_due = false


## Bootstrap announcement: tells the editor tab a GECS game is live so it can reply
## with a [code]gecs:subscribe[/code]. Flows on the base capability, before any
## subscription exists.
static func ready() -> bool:
	if _can_bootstrap():
		_send(Msg.READY, [])
	return true


## Route a message to the live debugger, or the test sink when one is installed.
## All senders funnel through here so the attach/sink policy lives in one place.
## Invariant: [param data] must be freshly built per call and never mutated after
## this returns — [method EngineDebugger.send_message] queues the array and the
## peer may encode it asynchronously on another thread.
static func _send(message: String, data: Array) -> void:
	if _test_sink.is_valid():
		_test_sink.call(message, data)
		return
	EngineDebugger.send_message(message, data)


static func world_init(world: World) -> bool:
	if can_send_message():
		_send(Msg.WORLD_INIT, [world.get_instance_id(), world.get_path()])
	return true


static func system_metric(system: System, time: float) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func system_last_run_data(system: System, last_run_data: Dictionary) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func set_world(world: World) -> bool:
	if can_send_message():
		_send(
			Msg.SET_WORLD,
			[world.get_instance_id(), world.get_path()] if world else [],
		)
	return true


static func process_world(delta: float, group_name: String) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func exit_world() -> bool:
	if can_send_message():
		_send(Msg.EXIT_WORLD, [])
	return true


static func entity_added(ent: Entity, in_tree: bool = true) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func entity_removed(ent_id: int, path: String) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func entity_disabled(ent: Entity) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func entity_enabled(ent: Entity) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func system_added(sys: System) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func system_removed(sys: System) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func _get_type_name_for_debugger(obj) -> String:
	if obj == null:
		return "null"
	if obj is Resource or obj is Node:
		var script = obj.get_script()
		if script:
			# Try to get class_name first
			var type_name = script.get_class()
			if type_name and type_name != "GDScript":
				return type_name
			# Otherwise use the resource path (e.g., "res://components/C_Health.gd")
			if script.resource_path:
				return script.resource_path  # Returns "C_Health"
		return obj.get_class()
	elif obj is Object:
		return obj.get_class()
	return str(typeof(obj))


static func entity_component_added(ent: Entity, comp: Resource) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func entity_component_removed(ent: Entity, comp: Resource) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


## Authoritative snapshot of an entity's current component ids (sent at the end of
## a poll). Lets the tab reconcile — prune rows for components removed while the
## lifecycle event category was off, or whose removal event was otherwise missed.
static func entity_components_synced(ent_id: int, comp_ids: Array) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


## Result of an ad-hoc query typed in the tab. [param entity_ids] are the matching
## entity instance ids (empty on error); [param error] is "" on success or a
## human-readable parse/eval message. Sent in reply to a "run_entity_query" pull,
## so it flows on the base attach state, not a category flag.
static func entity_query_result(entity_ids: Array, error: String) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func entity_component_property_changed(
	ent: Entity,
	comp: Resource,
	property_name: String,
	old_value: Variant,
	new_value: Variant,
) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


## Serialize a relationship for the editor: relation type + data and a typed
## target descriptor ("Freed" | "null" | "Entity" {id, path} | "Component"
## {type, data} | "Archetype" {script_path}). Shared by the lifecycle message
## and the step debugger's graph view.
static func serialize_relationship(rel: Relationship) -> Dictionary:
	var rel_data = {
		"relation_type": _get_type_name_for_debugger(rel.relation) if rel.relation else "null",
		"relation_data": rel.relation.serialize() if rel.relation else {},
		"target_type": "",
		"target_data": {},
	}
	# Format target based on type (freed checked first: a freed object
	# compares == null and `is` errors on a freed operand)
	if typeof(rel.target) == TYPE_OBJECT and not is_instance_valid(rel.target):
		rel_data["target_type"] = "Freed"
	elif rel.target == null:
		rel_data["target_type"] = "null"
	elif rel.target is Entity:
		rel_data["target_type"] = "Entity"
		rel_data["target_data"] = {
			"id": rel.target.get_instance_id(),
			"path": str(rel.target.get_path()) if rel.target.is_inside_tree() else String(rel.target.name),
		}
	elif rel.target is Component:
		rel_data["target_type"] = "Component"
		rel_data["target_data"] = {
			"type": _get_type_name_for_debugger(rel.target),
			"data": rel.target.serialize(),
		}
	elif rel.target is Script:
		rel_data["target_type"] = "Archetype"
		rel_data["target_data"] = {
			"script_path": rel.target.resource_path,
		}
	return rel_data


static func entity_relationship_added(ent: Entity, rel: Relationship) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


static func entity_relationship_removed(ent: Entity, rel: Relationship) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


## Deprecated sender. Use the Explorer debugger_state request.
static func step_state(state: Dictionary) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


## Step debugger: one completed step (or a breakpoint hit / external bucket)
## with its journaled ops. See GECSStepper for the log and op record shapes.
static func step_log(log: Dictionary) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true


## Graph view: nodes + edges for one graph's watched entities
## (GECSGraphState.build). [param graph_id] picks the editor window.
static func graph_state(graph_id: int, step_id: int, graph: Dictionary) -> bool:
	# Retired push API. Explorer v2 retrieves authoritative state on demand.
	return true
