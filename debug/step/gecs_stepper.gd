## GECSStepper: forward-only step debugger for a [World].
##
## Pauses ECS processing and runs it forward one unit at a time while the game
## keeps calling [method World.process] every frame. Granularities
## ([enum Kind]): FRAME (one main-loop iteration), GROUP (the rest of the
## current process group), SYSTEM (one system, including its PER_SYSTEM command
## flush), ARCHETYPE (one [method System.process] call), ENTITY (like
## ARCHETYPE, but each entity in the step set runs as its own call).[br]
## [br]
## Every structural mutation and emitted property change that happens during a
## step is journaled into that step's log (see [enum Op]); a diff sweep after
## each step catches writes that bypassed emitting setters. Breakpoints
## ([enum BpKind]) pause a live world before a system runs, or right after the
## system whose op matched. The graph watch feeds [GECSGraphState] to the
## editor after every step.[br]
## [br]
## Use it through the [World] API ([method World.debug_pause],
## [method World.debug_step], ...) or the editor debugger tab. Nothing here runs
## outside [method World.process]: commands only queue requests, and the game's
## own process() calls service them, so group order and delta stay exactly what
## the game produces.
class_name GECSStepper
extends RefCounted

## Step granularity.
enum Kind { FRAME, GROUP, SYSTEM, ARCHETYPE, ENTITY }

## Journal op codes: index 0 of every op record
## [code][op, entity_instance_id, entity_name, a, b, c, d, cause, system][/code].[br]
## PROP_SET / SWEEP_SET: a = component type, b = property, c = old, d = new.[br]
## COMP_ADD / COMP_REMOVE: a = component type, b = component instance id.[br]
## REL_ADD / REL_REMOVE: a = relation type, b = target label, c = relationship
## instance id, d = target entity instance id (0 when the target is not an entity).[br]
## ENTITY_ADD / ENTITY_REMOVE: a = node path (or name), b = component type names.[br]
## ENTITY_ENABLED: a = enabled.[br]
## EVENT: a = event name, b = payload.[br]
## [code]cause[/code] is "" for a direct write, "cmd" inside a CommandBuffer
## flush, "observer:<name>" inside an observer callback (nesting joined with
## ">"), "(sweep)" for sweep hits and "(external)" outside any step.
enum Op {
	PROP_SET,
	SWEEP_SET,
	COMP_ADD,
	COMP_REMOVE,
	REL_ADD,
	REL_REMOVE,
	ENTITY_ADD,
	ENTITY_REMOVE,
	ENTITY_ENABLED,
	EVENT,
}

## Breakpoint kinds.
enum BpKind { SYSTEM, COMPONENT_ADDED, COMPONENT_REMOVED, ENTITY, PROPERTY, QUERY }

const KIND_NAMES := ["frame", "group", "system", "archetype", "entity"]
const OP_NAMES := [
	"prop_set",
	"sweep_set",
	"comp_add",
	"comp_remove",
	"rel_add",
	"rel_remove",
	"entity_add",
	"entity_remove",
	"entity_enabled",
	"event",
]
const BP_KIND_NAMES := ["system", "component_added", "component_removed", "entity", "property", "query"]
## Ops kept per step log before it is marked truncated.
const MAX_OPS_PER_STEP := 2000
const MAX_STRING := 256
const MAX_CONTAINER := 32
## Step logs retained in [member step_logs].
const HISTORY := 64

enum _Result { WAIT, DONE }

var world: World
## True while the world is paused by the stepper.
var paused := false
## Run the silent-write diff sweep after every step (paused only).
var sweep_enabled := true
## Returns the current main-loop iteration id; a FRAME step spans one value.
## Headless tests inject a counter.
var frame_id_provider: Callable = Callable(Engine, "get_process_frames")
## Entity instance ids that get their own unit under [constant Kind.ENTITY].
var step_entities: Dictionary = {}
## Breakpoint id -> spec dictionary (see [method add_breakpoint]).
var breakpoints: Dictionary = {}
## Graph views keyed by graph id: [code]{id: {"watch": [entity instance ids], "depth": int}}[/code].
## The editor opens one floating graph window per id; code users default to id 0.
var graphs: Dictionary = {}
## Number of step / break / external log entries emitted so far.
var step_counter := 0
## Set by a component / entity breakpoint hit; consumed at the next boundary.
var break_requested := false
## The most recent step log (also delivered through [signal World.step_completed]).
var last_step_log: Dictionary = {}
## The last [constant HISTORY] step logs, oldest first.
var step_logs: Array = []

var _next_bp_id := 1
var _condition_ids: Array = []
var _bp_system_ids: Dictionary = {}
var _bp_comp_add_keys: Dictionary = {}
var _bp_comp_remove_keys: Dictionary = {}
var _bp_entity_ids: Dictionary = {}
var _break_info: Dictionary = {}
var _requests: Array = []
var _servicing := false
var _pause_settled := false
var _last_call_frame_id := -1
var _frame_step_id := -1
var _current_fid := -1
var _cursor: Dictionary = {}
var _in_step := false
var _step_kind := Kind.SYSTEM
var _step_label := ""
var _step_ops: Array = []
var _step_skipped: Array = []
var _carry_skipped: Array = []
var _step_systems: Array = []
var _step_truncated := false
var _step_started_usec := 0
var _external_ops: Array = []
var _live_scratch: Array = []
var _cause_stack: PackedStringArray = PackedStringArray()
var _cause := ""
var _current_system_name := ""
var _sweep := GECSDiffSweep.new()


func _init(owner: World) -> void:
	world = owner
	_reset_cursor()


#region Public API


## Pause ECS processing. The game's process() calls return immediately until
## [method resume] or a [method step] request.
func pause() -> void:
	if paused:
		return
	paused = true
	_pause_settled = false
	_last_call_frame_id = -1
	_frame_step_id = -1
	_reset_cursor()
	_sync_world_flags()
	_send_state()


## Resume live processing. A partially stepped system is finished first so its
## change baselines, command flush and clock advance are not skipped.
func resume() -> void:
	if not paused:
		return
	if _cursor.in_system:
		_drain_units_and_end()
	if _in_step:
		_frame_step_id = -1
		_finish_step()
	paused = false
	_requests.clear()
	_frame_step_id = -1
	_reset_cursor()
	_external_ops = []
	_sweep.clear()
	_sync_world_flags()
	_send_state()


## Queue [param count] steps of [param kind]. Pauses first when live.
func step(kind: int, count: int = 1) -> void:
	if kind < 0 or kind >= Kind.size():
		push_warning("GECSStepper.step: unknown kind %s" % str(kind))
		return
	if not paused:
		pause()
	_requests.append({"kind": kind, "count": maxi(1, count)})
	_send_state()


## Replace the step set (Entity instances or instance ids).
func set_step_entities(entities: Array) -> void:
	step_entities.clear()
	for item in entities:
		var iid := _to_instance_id(item)
		if iid != 0:
			step_entities[iid] = true
	_send_state()


func set_sweep(enabled: bool) -> void:
	sweep_enabled = enabled
	if enabled and paused and _pause_settled:
		_sweep.rebase(world)
	_send_state()


## Add a breakpoint. Spec shapes:[br]
## [code]{kind: "system", system: System | system_id: int | system_name: String}[/code][br]
## [code]{kind: "component_added" | "component_removed", component: Script | Component | "C_Health" | "res://...gd"}[/code][br]
## [code]{kind: "entity", entity: Entity | instance id}[/code][br]
## [code]kind[/code] also accepts a [enum BpKind] value. Returns the id, or 0 when
## the spec could not be resolved.
func add_breakpoint(spec: Dictionary) -> int:
	var kind := _parse_bp_kind(spec.get("kind"))
	if kind < 0:
		push_warning("GECSStepper.add_breakpoint: unknown kind %s" % str(spec.get("kind")))
		return 0
	var bp := {
		"id": _next_bp_id,
		"kind": kind,
		"kind_name": BP_KIND_NAMES[kind],
		"enabled": true,
		"hits": 0,
		"label": "",
		"system_id": 0,
		"comp_key": 0,
		"entity_id": 0,
	}
	match kind:
		BpKind.SYSTEM:
			var system := _resolve_system(spec)
			if system == null:
				push_warning("GECSStepper.add_breakpoint: system not found: %s" % str(spec))
				return 0
			bp.system_id = system.get_instance_id()
			bp.label = "before " + _system_label(system)
		BpKind.COMPONENT_ADDED, BpKind.COMPONENT_REMOVED:
			var script := _resolve_component_script(spec.get("component"))
			if script == null:
				push_warning("GECSStepper.add_breakpoint: component not found: %s" % str(spec))
				return 0
			bp.comp_key = script.get_instance_id()
			var verb := "added" if kind == BpKind.COMPONENT_ADDED else "removed"
			bp.label = "%s %s" % [script_label(script), verb]
		BpKind.ENTITY:
			var iid := _to_instance_id(spec.get("entity"))
			if iid == 0:
				push_warning("GECSStepper.add_breakpoint: entity not found: %s" % str(spec))
				return 0
			bp.entity_id = iid
			var entity = instance_from_id(iid)
			bp.label = "entity %s touched" % (String(entity.name) if entity else str(iid))
		BpKind.PROPERTY, BpKind.QUERY:
			var service := world.debug_explorer()
			var condition := spec.duplicate(true)
			condition["kind"] = "property" if kind == BpKind.PROPERTY else "query"
			var initial := service.condition_value(condition)
			if initial.has("error"): return 0
			bp["condition"] = condition
			bp["previous"] = initial.value
			bp["matched"] = service.condition_matches(condition, initial.value, null)
			bp.label = str(spec.get("label", "%s %s" % [condition.kind, condition.get("op", "changed")]))

	_next_bp_id += 1
	breakpoints[bp.id] = bp
	_rebuild_bp_sets()
	_sync_world_flags()
	_send_state()
	return bp.id


func remove_breakpoint(breakpoint_id: int) -> void:
	if breakpoints.erase(breakpoint_id):
		_rebuild_bp_sets()
		_sync_world_flags()
		_send_state()


func set_breakpoint_enabled(breakpoint_id: int, enabled: bool) -> void:
	if not breakpoints.has(breakpoint_id):
		return
	breakpoints[breakpoint_id].enabled = enabled
	_rebuild_bp_sets()
	_sync_world_flags()
	_send_state()


func clear_breakpoints() -> void:
	breakpoints.clear()
	_rebuild_bp_sets()
	_sync_world_flags()
	_send_state()


## Replace the watch set of graph [param graph_id] (Entity instances or
## instance ids) and push its payload right away. An empty set closes the graph.
func set_graph_watch(entities: Array, depth: int = 0, graph_id: int = 0) -> void:
	var watch: Array = []
	for item in entities:
		var iid := _to_instance_id(item)
		if iid != 0 and not watch.has(iid):
			watch.append(iid)
	if watch.is_empty():
		close_graph(graph_id)
		return
	graphs[graph_id] = {"watch": watch, "depth": maxi(0, depth)}
	_send_state()
	send_graph_state(graph_id)


## Drop graph [param graph_id]; nothing is pushed for it any more.
func close_graph(graph_id: int = 0) -> void:
	if graphs.erase(graph_id):
		_send_state()


## Build the payload of graph [param graph_id] (an empty graph for unknown ids).
func graph_state(graph_id: int = 0) -> Dictionary:
	var g: Dictionary = graphs.get(graph_id, {})
	return GECSGraphState.build(world, g.get("watch", []), int(g.get("depth", 0)))


## Push graph payloads to the editor: one graph, or every open graph when
## [param graph_id] is -1. No-op for unknown ids.
func send_graph_state(graph_id: int = -1) -> void:
	if graph_id == -1:
		for id in graphs.keys():
			GECSEditorDebuggerMessages.graph_state(id, step_counter, graph_state(id))
	elif graphs.has(graph_id):
		GECSEditorDebuggerMessages.graph_state(graph_id, step_counter, graph_state(graph_id))


## Snapshot of the stepper: paused flag, cursor, step set, breakpoints, graphs.
func state() -> Dictionary:
	var cursor := {
		"has_group": _cursor.group != null,
		"group": String(_cursor.group) if _cursor.group != null else "",
		"slot": _cursor.slot,
		"system_id": 0,
		"system_name": "",
		"in_system": _cursor.in_system,
		"unit_index": _cursor.unit_i,
		"unit_count": _cursor.units.size(),
		"unit_label": "",
		"next_label": "",
	}
	if _cursor.group != null:
		var gs := _group_systems()
		if _cursor.in_system and is_instance_valid(_cursor.system):
			cursor.system_id = _cursor.system.get_instance_id()
			cursor.system_name = _system_label(_cursor.system)
			if _cursor.unit_i < _cursor.units.size():
				cursor.unit_label = _cursor.units[_cursor.unit_i].label
		elif _cursor.slot < gs.size():
			cursor.system_id = gs[_cursor.slot].get_instance_id()
			cursor.system_name = _system_label(gs[_cursor.slot])
		elif _group_has_pending_flush():
			cursor.next_label = "(group flush)"
		else:
			cursor.next_label = "(end of group)"
	var bps := []
	for bp in breakpoints.values():
		bps.append(bp.duplicate())
	return {
		"paused": paused,
		"cursor": cursor,
		"step_entities": step_entities.keys(),
		"sweep_enabled": sweep_enabled,
		"breakpoints": bps,
		"graphs": graphs.duplicate(true),
		"step_counter": step_counter,
		"pending_requests": _requests.size(),
		"frame_step_active": _frame_step_id != -1,
		"break_info": _break_info.duplicate(),
	}


## World teardown (purge): resume, drop the cursor, journal, step set and graphs.
## Breakpoints survive; entity breakpoints whose entity is gone are pruned.
func reset() -> void:
	paused = false
	_requests.clear()
	_reset_cursor()
	_in_step = false
	_frame_step_id = -1
	_step_ops = []
	_step_skipped = []
	_carry_skipped = []
	_step_systems = []
	_external_ops = []
	_live_scratch = []
	step_entities.clear()
	graphs.clear()
	_sweep.clear()
	break_requested = false
	_break_info = {}
	step_logs = []
	last_step_log = {}
	step_counter = 0
	sweep_enabled = true
	_pause_settled = false
	_last_call_frame_id = -1
	for bp_id in breakpoints.keys():
		var bp: Dictionary = breakpoints[bp_id]
		if bp.kind == BpKind.ENTITY and instance_from_id(bp.entity_id) == null:
			breakpoints.erase(bp_id)
	_rebuild_bp_sets()
	_sync_world_flags()


## Editor -> game command channel (names as sent by the debugger tab, without
## the "gecs:" prefix). Returns false for unknown messages.
func handle_command(message: String, data: Array) -> bool:
	match message:
		"step_pause":
			pause()
		"step_resume":
			resume()
		"step":
			var kind := _parse_kind(data[0] if data.size() > 0 else Kind.SYSTEM)
			if kind < 0:
				return false
			step(kind, int(data[1]) if data.size() > 1 else 1)
		"step_set_entities":
			set_step_entities(data[0] if data.size() > 0 and data[0] is Array else [])
		"step_set_sweep":
			set_sweep(bool(data[0]) if data.size() > 0 else true)
		"step_pull_state":
			_send_state()
		"breakpoint_add":
			if data.size() > 0 and data[0] is Dictionary:
				add_breakpoint(data[0])
		"breakpoint_remove":
			if data.size() > 0:
				remove_breakpoint(int(data[0]))
		"breakpoint_set_enabled":
			if data.size() > 1:
				set_breakpoint_enabled(int(data[0]), bool(data[1]))
		"breakpoint_clear":
			clear_breakpoints()
		"graph_watch":
			# [graph_id, ids, depth]
			if data.size() > 1 and data[1] is Array:
				set_graph_watch(data[1], int(data[2]) if data.size() > 2 else 0, int(data[0]))
		"graph_pull":
			# [graph_id]; no id pushes every open graph.
			send_graph_state(int(data[0]) if data.size() > 0 else -1)
		"graph_close":
			if data.size() > 0:
				close_graph(int(data[0]))
		_:
			return false
	return true


#endregion Public API

#region World integration (paused path)


## Owns the game's process() call while paused. Services pending step requests
## for [param group] or returns immediately.
func _process_paused(delta: float, group: String) -> void:
	if _servicing:
		return
	var fid: int = frame_id_provider.call()
	_current_fid = fid
	if not _pause_settled:
		# First paused call: the pause command may have landed mid-frame, so
		# this call is never treated as the first call of an iteration.
		_pause_settled = true
		_last_call_frame_id = fid
		if sweep_enabled:
			_sweep.rebase(world)
	if _requests.is_empty():
		_last_call_frame_id = fid
		return
	_servicing = true
	var first_of_frame := fid != _last_call_frame_id
	while not _requests.is_empty() and paused:
		var req: Dictionary = _requests[0]
		var result := _service_one(req, delta, group, fid, first_of_frame)
		if result == _Result.WAIT:
			break
		req.count -= 1
		if req.count <= 0:
			_requests.pop_front()
		# Another step in this same call needs the cursor to still be inside this
		# group, or a fresh iteration (a FRAME step that just closed on this call).
		if _cursor.group == null and not first_of_frame:
			break
	_servicing = false
	_last_call_frame_id = fid
	_send_state()


func _service_one(req: Dictionary, delta: float, group: String, fid: int, first_of_frame: bool) -> int:
	match int(req.kind):
		Kind.FRAME:
			return _step_frame(delta, group, fid, first_of_frame)
		Kind.GROUP:
			return _step_group(delta, group)
		Kind.SYSTEM:
			return _step_system(delta, group)
		Kind.ARCHETYPE, Kind.ENTITY:
			return _step_unit(int(req.kind), delta, group)
	return _Result.DONE


## FRAME = one main-loop iteration: starts on the first process() call whose
## frame id differs from the previous paused call, runs every group call that
## shares that id, and completes (without running) on the first call with a new
## id. A cursor already inside a group finishes that group and the rest of its
## iteration instead.
func _step_frame(delta: float, group: String, fid: int, first_of_frame: bool) -> int:
	if _frame_step_id == -1:
		if _cursor.group == null:
			if not first_of_frame:
				return _Result.WAIT
		elif _cursor.group != group:
			return _Result.WAIT
		_frame_step_id = fid
		_begin_step(Kind.FRAME, "(frame %d)" % fid)
	elif fid != _frame_step_id:
		_frame_step_id = -1
		_finish_step()
		return _Result.DONE
	if not _ensure_group(group, delta):
		return _Result.WAIT
	_run_rest_of_group()
	if break_requested:
		_frame_step_id = -1
		_finish_step()
		return _Result.DONE
	return _Result.WAIT


func _step_group(delta: float, group: String) -> int:
	if not _ensure_group(group, delta):
		return _Result.WAIT
	_begin_step(Kind.GROUP, "(group '%s')" % group)
	_run_rest_of_group()
	_finish_step()
	return _Result.DONE


func _step_system(delta: float, group: String) -> int:
	if not _ensure_group(group, delta):
		return _Result.WAIT
	if _cursor.in_system:
		_begin_step(Kind.SYSTEM, _system_label(_cursor.system))
		_drain_units_and_end()
		_finish_step()
		return _Result.DONE
	while true:
		var gs := _group_systems()
		if _cursor.slot >= gs.size():
			if _group_has_pending_flush():
				_begin_step(Kind.SYSTEM, "(group flush)")
				_run_group_flush()
				_close_group()
				_finish_step()
				return _Result.DONE
			_close_group()
			return _Result.WAIT
		var system: System = gs[_cursor.slot]
		if not _system_would_run(system):
			_carry_skipped.append(_system_label(system))
			_advance_slot(gs, system)
			continue
		_begin_step(Kind.SYSTEM, _system_label(system))
		_run_system_full(system)
		_finish_step()
		return _Result.DONE
	return _Result.WAIT


func _step_unit(kind: int, delta: float, group: String) -> int:
	if not _ensure_group(group, delta):
		return _Result.WAIT
	if not _cursor.in_system:
		while true:
			var gs := _group_systems()
			if _cursor.slot >= gs.size():
				if _group_has_pending_flush():
					_begin_step(kind, "(group flush)")
					_run_group_flush()
					_close_group()
					_finish_step()
					return _Result.DONE
				_close_group()
				return _Result.WAIT
			var system: System = gs[_cursor.slot]
			if not _system_would_run(system):
				_carry_skipped.append(_system_label(system))
				_advance_slot(gs, system)
				continue
			_begin_step(kind, _system_label(system))
			if not _begin_system_units(system, kind):
				_carry_skipped.append(_system_label(system))
				continue
			break
	else:
		_begin_step(kind, _system_label(_cursor.system))
	if not is_instance_valid(_cursor.system):
		_abandon_system()
		_finish_step()
		return _Result.DONE
	if _cursor.units.is_empty():
		_step_label = "%s (no matching entities)" % _system_label(_cursor.system)
		_end_system_units()
		_finish_step()
		return _Result.DONE
	var unit: Dictionary = _cursor.units[_cursor.unit_i]
	_step_label = "%s / %s" % [_system_label(_cursor.system), unit.label]
	_run_unit(unit)
	_cursor.unit_i += 1
	if is_instance_valid(_cursor.system):
		if _cursor.unit_i >= _cursor.units.size():
			_load_next_units(kind)
		if _cursor.units.is_empty():
			_end_system_units()
	else:
		_abandon_system()
	_finish_step()
	return _Result.DONE


## Adopt [param group] when the cursor is free. False = this call must be
## skipped (wrong group, or a group with no systems, which live treats as a
## no-op too).
func _ensure_group(group: String, delta: float) -> bool:
	if _cursor.group != null:
		return _cursor.group == group
	if not world.systems_by_group.has(group):
		return false
	_cursor.group = group
	_cursor.delta = delta
	_cursor.slot = 0
	_cursor.in_system = false
	# Timers advance once per group pass, exactly as the live loop does before
	# any system in the group runs.
	if world._timers_dirty:
		world._rebuild_group_timers()
	if world._group_timers.has(group):
		for timer in world._group_timers[group]:
			timer.advance(delta)
	return true


func _close_group() -> void:
	_cursor.group = null
	_cursor.slot = 0
	_cursor.in_system = false
	_cursor.system = null
	_cursor.units = []
	_cursor.unit_i = 0


func _reset_cursor() -> void:
	_cursor = {
		"group": null,
		"delta": 0.0,
		"slot": 0,
		"system": null,
		"in_system": false,
		"units": [],
		"unit_i": 0,
	}


func _group_systems() -> Array:
	if _cursor.group == null:
		return []
	var gs = world.systems_by_group.get(_cursor.group)
	return gs if gs != null else []


## Same slot re-check as the live loop: advance only if the slot still holds
## this system (a removal at or before it shifted the next one into the slot).
func _advance_slot(gs: Array, system: System) -> void:
	if _cursor.slot < gs.size() and gs[_cursor.slot] == system:
		_cursor.slot += 1


func _group_has_pending_flush() -> bool:
	for system in _group_systems():
		if (
			is_instance_valid(system)
			and system.command_buffer_flush_mode == System.FlushMode.PER_GROUP
			and system.has_pending_commands()
		):
			return true
	return false


## Mirror of the PER_GROUP flush loop in World.process.
func _run_group_flush() -> void:
	_current_system_name = "(group flush)"
	var fs := _group_systems()
	var i := 0
	while i < fs.size():
		var system: System = fs[i]
		if (
			is_instance_valid(system)
			and system.command_buffer_flush_mode == System.FlushMode.PER_GROUP
			and system.has_pending_commands()
		):
			system.cmd.execute()
		if i < fs.size() and fs[i] == system:
			i += 1
		fs = _group_systems()
	_check_conditions()
	_current_system_name = ""


## Run every remaining system in the cursor's group (via _handle, byte-identical
## to live), then the group flush, then close the group. Stops after the system
## that triggered a breakpoint.
func _run_rest_of_group() -> void:
	if _cursor.in_system:
		_drain_units_and_end()
	while not break_requested:
		var gs := _group_systems()
		if _cursor.slot >= gs.size():
			break
		var system: System = gs[_cursor.slot]
		if not _system_would_run(system):
			_step_skipped.append(_system_label(system))
			_advance_slot(gs, system)
			continue
		_run_system_full(system)
	if break_requested:
		return
	if _group_has_pending_flush():
		_run_group_flush()
	_close_group()


func _run_system_full(system: System) -> void:
	_current_system_name = _system_label(system)
	_step_systems.append(system)
	system._handle(_cursor.delta)
	_check_conditions()
	_current_system_name = ""
	_advance_slot(_group_systems(), system)


func _begin_system_units(system: System, kind: int) -> bool:
	_cursor.system = system
	_cursor.in_system = true
	_cursor.units = []
	_cursor.unit_i = 0
	_step_systems.append(system)
	_current_system_name = _system_label(system)
	if not system._step_begin(_cursor.delta):
		_cursor.in_system = false
		_cursor.system = null
		_current_system_name = ""
		_advance_slot(_group_systems(), system)
		return false
	_load_next_units(kind)
	return true


## Pull batches from the system until one yields units (or none remain).
func _load_next_units(kind: int) -> void:
	_cursor.units = []
	_cursor.unit_i = 0
	var system: System = _cursor.system
	while is_instance_valid(system):
		var batch: Dictionary = system._step_next_batch(_cursor.delta)
		if batch.is_empty():
			return
		batch.label = _batch_label(batch)
		var units := _split_units(batch, kind)
		if not units.is_empty():
			_cursor.units = units
			return


func _run_unit(unit: Dictionary) -> void:
	var system: System = _cursor.system
	var entities: Array[Entity] = unit.entities
	var components: Array = unit.components
	if unit.sliced:
		# Slices are copies; entities freed or removed since the slice was cut
		# must not reach user code.
		var live: Array[Entity] = []
		var keep: Array = []
		for i in entities.size():
			var e = entities[i]
			if is_instance_valid(e) and world.entity_to_archetype.has(e):
				live.append(e)
				keep.append(i)
		if live.size() != entities.size():
			if live.is_empty():
				_step_skipped.append("%s (entities gone)" % unit.label)
				return
			entities = live
			var cols := []
			for col in components:
				var c := []
				for i in keep:
					c.append(col[i])
				cols.append(c)
			components = cols
	_current_system_name = _system_label(system)
	system._step_run(entities, components, unit.callable, _cursor.delta)
	_check_conditions()


func _end_system_units() -> void:
	var system: System = _cursor.system
	if is_instance_valid(system):
		_current_system_name = _system_label(system)
		system._step_end(_cursor.delta)
		_check_conditions()
	_current_system_name = ""
	_cursor.in_system = false
	_cursor.units = []
	_cursor.unit_i = 0
	_advance_slot(_group_systems(), system)
	_cursor.system = null


func _abandon_system() -> void:
	_step_skipped.append("(system freed mid-step)")
	_current_system_name = ""
	_cursor.in_system = false
	_cursor.units = []
	_cursor.unit_i = 0
	_cursor.system = null


func _drain_units_and_end() -> void:
	while is_instance_valid(_cursor.system) and not _cursor.units.is_empty():
		_run_unit(_cursor.units[_cursor.unit_i])
		_cursor.unit_i += 1
		if _cursor.unit_i >= _cursor.units.size():
			_load_next_units(Kind.ARCHETYPE)
	if is_instance_valid(_cursor.system):
		_end_system_units()
	else:
		_abandon_system()


## ARCHETYPE: the batch is one unit (zero-copy, exactly what live passes).
## ENTITY with a step set: each member entity becomes its own unit, contiguous
## non-members run together, archetype order preserved (slices are copies).
func _split_units(batch: Dictionary, kind: int) -> Array:
	if kind != Kind.ENTITY or step_entities.is_empty():
		return [
			{
				"entities": batch.entities,
				"components": batch.components,
				"callable": batch.callable,
				"label": batch.label,
				"sliced": false,
				"focus": 0,
			}
		]
	var ents: Array = batch.entities
	var units: Array = []
	var run_start := -1
	for i in ents.size():
		var e = ents[i]
		var iid: int = e.get_instance_id() if is_instance_valid(e) else 0
		if step_entities.has(iid):
			if run_start >= 0:
				units.append(_slice_unit(batch, run_start, i, 0))
				run_start = -1
			units.append(_slice_unit(batch, i, i + 1, iid))
		elif run_start < 0:
			run_start = i
	if run_start >= 0:
		units.append(_slice_unit(batch, run_start, ents.size(), 0))
	return units


func _slice_unit(batch: Dictionary, from: int, to: int, focus: int) -> Dictionary:
	var ents: Array[Entity] = []
	ents.assign(batch.entities.slice(from, to))
	var cols := []
	for col in batch.components:
		cols.append(col.slice(from, to))
	var label: String
	if focus != 0:
		var focused = ents[0] if not ents.is_empty() else null
		label = (
			"%s / entity %s"
			% [batch.label, String(focused.name) if is_instance_valid(focused) else str(focus)]
		)
	else:
		label = "%s / %d entities" % [batch.label, ents.size()]
	return {
		"entities": ents,
		"components": cols,
		"callable": batch.callable,
		"label": label,
		"sliced": true,
		"focus": focus,
	}


func _batch_label(batch: Dictionary) -> String:
	var arch = batch.get("archetype")
	if arch == null:
		return "filtered set"
	var parts := []
	for key in arch.component_types:
		if key is String:
			parts.append(_rel_key_label(key))
		else:
			var script = world._component_script_cache.get(key)
			if script == null:
				script = instance_from_id(key)
			parts.append(script_label(script) if script is Script else str(key))
	return "[%s]" % ", ".join(parts)


static func _rel_key_label(slot_key: String) -> String:
	# "rel://res://x/c_likes.gd::entity#5" -> "rel:c_likes->entity#5"
	var body := slot_key.trim_prefix("rel://")
	var parts := body.split("::", true, 1)
	var rel_name := parts[0].get_file().get_basename()
	var target := parts[1] if parts.size() > 1 else "*"
	if target.begins_with("comp://") or target.begins_with("script://"):
		target = target.get_file().get_basename()
	return "rel:%s->%s" % [rel_name, target]


#endregion World integration (paused path)

#region World integration (live path: breakpoints)


## process() entry while breakpoints exist. A break requested outside process()
## (external code) pauses here, at a call boundary.
func _live_process_entry(_group: String) -> bool:
	if break_requested:
		_pause_from_live(null, 0, 0.0, "(external)")
		return true
	_live_scratch.clear()
	return false


## Before a system runs live. A system breakpoint pauses here WITHOUT running it.
func _live_before_system(system: System, group: String, slot: int, delta: float) -> bool:
	_current_system_name = _system_label(system)
	if (
		not _bp_system_ids.is_empty()
		and _bp_system_ids.has(system.get_instance_id())
		and _system_would_run(system)
	):
		var bp_id: int = _bp_system_ids[system.get_instance_id()]
		var bp: Dictionary = breakpoints[bp_id]
		bp.hits += 1
		_break_info = {
			"breakpoint_id": bp_id,
			"label": bp.label,
			"op": "",
			"entity_id": 0,
			"entity_name": "",
			"system": _current_system_name,
		}
		_current_system_name = ""
		_pause_from_live(group, slot, delta, "(external)")
		return true
	return false


## After a system ran live. A component / entity breakpoint hit inside it
## pauses here, with the system's ops as the log entry.
func _live_after_system(group: String, slot: int, delta: float) -> bool:
	_check_conditions()
	var label := _current_system_name
	_current_system_name = ""
	if break_requested:
		_pause_from_live(group, slot, delta, label)
		return true
	_live_scratch.clear()
	return false


func _live_after_flush(_group: String) -> bool:
	_check_conditions()
	if break_requested:
		_pause_from_live(null, 0, 0.0, "(group flush)")
		return true
	_live_scratch.clear()
	return false


func _pause_from_live(group, slot: int, delta: float, label: String) -> void:
	paused = true
	# A live break happens at a known safe point inside a process() call, so the
	# pause is settled right away: the next call with a request services it and
	# a FRAME step waits for the next iteration (same frame id = same iteration).
	_pause_settled = true
	_current_fid = frame_id_provider.call()
	_last_call_frame_id = _current_fid
	_frame_step_id = -1
	_reset_cursor()
	if group != null:
		# The group's timers already advanced this call; keeping the cursor inside
		# the group means they are not advanced again when stepping resumes it.
		_cursor.group = group
		_cursor.slot = slot
		_cursor.delta = delta
	if sweep_enabled:
		_sweep.rebase(world)
	var info := _break_info
	var log := _make_log(-1, "break: " + label, _live_scratch, [], [], 0.0, false, info)
	log["kind_name"] = "break"
	_live_scratch = []
	_break_info = {}
	break_requested = false
	_sync_world_flags()
	_publish_log(log)
	_send_state()
	send_graph_state()
	world.step_break_hit.emit(int(info.get("breakpoint_id", 0)), log)


#endregion World integration (live path: breakpoints)

#region Journal hooks (called from World / Entity / CommandBuffer funnels)


func _on_component_added(entity: Entity, component: Resource) -> void:
	_record(Op.COMP_ADD, entity, type_name_of(component), _instance_id_of(component), null, null)
	if not _bp_comp_add_keys.is_empty():
		var key := _comp_key(component)
		if _bp_comp_add_keys.has(key):
			_request_break(_bp_comp_add_keys[key], Op.COMP_ADD, entity)


func _on_component_removed(entity: Entity, component: Resource) -> void:
	_record(Op.COMP_REMOVE, entity, type_name_of(component), _instance_id_of(component), null, null)
	if not _bp_comp_remove_keys.is_empty():
		var key := _comp_key(component)
		if _bp_comp_remove_keys.has(key):
			_request_break(_bp_comp_remove_keys[key], Op.COMP_REMOVE, entity)


func _on_property_changed(
	entity: Entity, component: Resource, property: String, old_value: Variant, new_value: Variant
) -> void:
	if paused:
		_sweep.note_written(component, property)
	_record(
		Op.PROP_SET,
		entity,
		type_name_of(component),
		property,
		encode_value(old_value),
		encode_value(new_value)
	)


func _on_relationship_added(entity: Entity, rel: Relationship) -> void:
	_record(
		Op.REL_ADD,
		entity,
		_relation_label(rel),
		_target_label(rel),
		_instance_id_of(rel),
		_target_entity_id(rel)
	)


func _on_relationship_removed(entity: Entity, rel: Relationship) -> void:
	_record(
		Op.REL_REMOVE,
		entity,
		_relation_label(rel),
		_target_label(rel),
		_instance_id_of(rel),
		_target_entity_id(rel)
	)


func _on_entity_added(entity: Entity) -> void:
	_record(Op.ENTITY_ADD, entity, _entity_path(entity), _component_names(entity), null, null)


func _on_entity_removed(entity: Entity) -> void:
	_record(Op.ENTITY_REMOVE, entity, _entity_path(entity), _component_names(entity), null, null)
	var iid := entity.get_instance_id()
	step_entities.erase(iid)
	for g in graphs.values():
		g.watch.erase(iid)


func _on_entity_enabled(entity: Entity, enabled: bool) -> void:
	_record(Op.ENTITY_ENABLED, entity, enabled, null, null, null)


func _on_event(event_name: StringName, entity: Entity, data: Variant) -> void:
	_record(Op.EVENT, entity, String(event_name), encode_value(data), null, null)


## Attribute nested mutations (CommandBuffer flush, observer callbacks).
func push_cause(label: String) -> void:
	_cause_stack.append(label)
	_cause = ">".join(_cause_stack)


func pop_cause() -> void:
	if _cause_stack.is_empty():
		return
	_cause_stack.remove_at(_cause_stack.size() - 1)
	_cause = ">".join(_cause_stack)


func _record(op: int, entity, a, b, c, d) -> void:
	var iid := 0
	var ename := ""
	if entity != null and is_instance_valid(entity):
		iid = entity.get_instance_id()
		ename = String(entity.name)
	var cause := _cause
	if _current_system_name == "" and not _in_step:
		cause = "(external)" if cause == "" else "(external)>" + cause
	_append_op([op, iid, ename, a, b, c, d, cause, _current_system_name])
	if iid != 0 and not _bp_entity_ids.is_empty() and _bp_entity_ids.has(iid):
		_request_break(_bp_entity_ids[iid], op, entity)


func _append_op(rec: Array) -> void:
	var target: Array
	if _in_step:
		target = _step_ops
	elif paused:
		target = _external_ops
	else:
		target = _live_scratch
	if target.size() >= MAX_OPS_PER_STEP:
		if _in_step:
			_step_truncated = true
		return
	target.append(rec)


func _request_break(bp_id: int, op: int, entity) -> void:
	if break_requested:
		return
	var bp: Dictionary = breakpoints.get(bp_id, {})
	if bp.is_empty():
		return
	bp.hits += 1
	break_requested = true
	var valid := entity != null and is_instance_valid(entity)
	_break_info = {
		"breakpoint_id": bp_id,
		"label": bp.label,
		"op": OP_NAMES[op],
		"entity_id": entity.get_instance_id() if valid else 0,
		"entity_name": String(entity.name) if valid else "",
		"system": _current_system_name,
	}
	_sync_world_flags()


#endregion Journal hooks

#region Step bookkeeping


func _begin_step(kind: int, label: String) -> void:
	_in_step = true
	_step_kind = kind
	_step_label = label
	_step_started_usec = Time.get_ticks_usec()
	_step_skipped = _carry_skipped
	_carry_skipped = []


func _finish_step() -> void:
	var elapsed_ms := (Time.get_ticks_usec() - _step_started_usec) / 1000.0
	# Silent writes: diff every component against the pre-step baseline. Still
	# inside the step, so the records land in this step's ops.
	if sweep_enabled and paused:
		for rec in _sweep.diff(world):
			_append_op(
				[
					Op.SWEEP_SET,
					rec[0],
					rec[1],
					rec[2],
					rec[3],
					encode_value(rec[4]),
					encode_value(rec[5]),
					"(sweep)",
					"",
				]
			)
	_in_step = false
	# Ops made between the previous step and this one (editor pokes, game code
	# outside process) are published first, as their own entry.
	if not _external_ops.is_empty():
		var ext_log := _make_log(-1, "(external)", _external_ops, [], [], 0.0, false, {})
		ext_log["kind_name"] = "external"
		_external_ops = []
		_publish_log(ext_log)
	var log := _make_log(
		_step_kind,
		_step_label,
		_step_ops,
		_step_skipped,
		_step_systems,
		elapsed_ms,
		_step_truncated,
		_break_info
	)
	var systems_run: Array = _step_systems
	var kind := _step_kind
	_step_ops = []
	_step_skipped = []
	_step_systems = []
	_step_truncated = false
	_break_info = {}
	break_requested = false
	_sync_world_flags()
	_publish_log(log)
	_send_state()
	send_graph_state()
	if ECS.debug and GECSEditorDebuggerMessages.attached and GECSEditorDebuggerMessages.telemetry_active:
		for system in systems_run:
			if is_instance_valid(system):
				GECSEditorDebuggerMessages.system_last_run_data(system, system.lastRunData)
	world.step_completed.emit(kind, log)


func _make_log(
	kind: int, label: String, ops: Array, skipped: Array, systems: Array, ms: float, truncated: bool, brk: Dictionary
) -> Dictionary:
	var names := []
	for system in systems:
		if is_instance_valid(system):
			names.append(_system_label(system))
	var system_id := 0
	if systems.size() == 1 and is_instance_valid(systems[0]):
		system_id = systems[0].get_instance_id()
	var touched := {}
	for op in ops:
		if op[1] != 0:
			touched[op[1]] = true
	return {
		"step_id": step_counter + 1,
		"kind": kind,
		"kind_name": KIND_NAMES[kind] if kind >= 0 and kind < KIND_NAMES.size() else "external",
		"label": label,
		"frame": _current_fid,
		"group": String(_cursor.group) if _cursor.group != null else "",
		"system_id": system_id,
		"systems": names,
		"skipped": skipped.duplicate(),
		"ops": ops,
		"op_count": ops.size(),
		"truncated": truncated,
		"ms": ms,
		"touched": touched.keys(),
		"break_info": brk.duplicate(),
	}


func _publish_log(log: Dictionary) -> void:
	step_counter += 1
	log["step_id"] = step_counter
	last_step_log = log
	step_logs.append(log)
	if step_logs.size() > HISTORY:
		step_logs.pop_front()
	GECSEditorDebuggerMessages.step_log(log)


func _send_state() -> void:
	GECSEditorDebuggerMessages.step_state(state())


func _sync_world_flags() -> void:
	var bp_hooks := not (
		_bp_comp_add_keys.is_empty() and _bp_comp_remove_keys.is_empty() and _bp_entity_ids.is_empty() and _condition_ids.is_empty()
	)
	world._step_paused = paused
	world._step_hooks_active = paused or bp_hooks
	world._step_live_checks = (
		not paused and (bp_hooks or not _bp_system_ids.is_empty() or break_requested)
	)


func _rebuild_bp_sets() -> void:
	_condition_ids.clear()
	_bp_system_ids.clear()
	_bp_comp_add_keys.clear()
	_bp_comp_remove_keys.clear()
	_bp_entity_ids.clear()
	for bp in breakpoints.values():
		if not bp.enabled:
			continue
		match int(bp.kind):
			BpKind.SYSTEM:
				_bp_system_ids[bp.system_id] = bp.id
			BpKind.COMPONENT_ADDED:
				_bp_comp_add_keys[bp.comp_key] = bp.id
			BpKind.COMPONENT_REMOVED:
				_bp_comp_remove_keys[bp.comp_key] = bp.id
			BpKind.ENTITY:
				_bp_entity_ids[bp.entity_id] = bp.id
			BpKind.PROPERTY, BpKind.QUERY:
				_condition_ids.append(bp.id)


func _check_conditions() -> void:
	if world._explorer != null and not break_requested: world._explorer.check_run_boundary()
	if _condition_ids.is_empty() or break_requested: return
	var service := world.debug_explorer()
	for id in _condition_ids.duplicate():
		var bp: Dictionary = breakpoints.get(id, {})
		if bp.is_empty(): continue
		var current := service.condition_value(bp.condition)
		if current.has("error"):
			bp.enabled = false
			bp["error"] = current.error
			continue
		var matches := service.condition_matches(bp.condition, current.value, bp.previous)
		var transition := str(bp.condition.get("op", "changed")) in ["changed", "entered", "left"]
		if matches and (transition or not bp.matched):
			bp.hits += 1
			break_requested = true
			_break_info = {"breakpoint_id": id, "label": bp.label, "system": _current_system_name, "op": "condition"}
		bp.previous = current.value.duplicate(true) if current.value is Array or current.value is Dictionary else current.value
		bp.matched = matches
	_rebuild_bp_sets()
	_sync_world_flags()


#endregion Step bookkeeping

#region Resolution and labels


static func _system_would_run(system: System) -> bool:
	if not is_instance_valid(system) or not system.active or system.paused:
		return false
	return system.tick_source == null or system.tick_source.ticked


static func _system_label(system: System) -> String:
	if not is_instance_valid(system):
		return "<freed>"
	# Node names are what users see in the scene tree (and stay distinct for
	# several systems sharing one script). Godot auto-names unnamed and
	# colliding nodes with an "@" pattern that carries no information; prefer
	# the script basename then.
	var node_name := String(system.name)
	if node_name != "" and not node_name.begins_with("@"):
		return node_name
	if system._debug_name != "":
		return system._debug_name
	return "System#%d" % system.get_instance_id()


func _parse_kind(value) -> int:
	if typeof(value) == TYPE_INT:
		return value if value >= 0 and value < Kind.size() else -1
	var idx := KIND_NAMES.find(String(value).to_lower())
	return idx


func _parse_bp_kind(value) -> int:
	if typeof(value) == TYPE_INT:
		return value if value >= 0 and value < BpKind.size() else -1
	return BP_KIND_NAMES.find(String(value).to_lower())


func _resolve_system(spec: Dictionary) -> System:
	var direct = spec.get("system")
	if direct is System and is_instance_valid(direct):
		return direct
	var system_id: int = int(spec.get("system_id", 0))
	if system_id != 0:
		var obj = instance_from_id(system_id)
		if obj is System:
			return obj
	var system_name: String = String(spec.get("system_name", ""))
	if system_name != "":
		for system in world.systems:
			if is_instance_valid(system) and _system_label(system) == system_name:
				return system
	return null


func _resolve_component_script(value) -> Script:
	if value is Script:
		return value
	if value is Resource and is_instance_valid(value) and value.get_script() != null:
		return value.get_script()
	if typeof(value) == TYPE_INT:
		var obj = instance_from_id(value)
		return obj if obj is Script else null
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return world._debug_class_script(String(value))
	return null


static func _to_instance_id(item) -> int:
	if item is Entity:
		return item.get_instance_id() if is_instance_valid(item) else 0
	if typeof(item) == TYPE_INT:
		var obj = instance_from_id(item)
		return item if obj is Entity else 0
	return 0


static func _comp_key(component: Resource) -> int:
	if component == null or not is_instance_valid(component):
		return 0
	var script = component.get_script()
	return script.get_instance_id() if script != null else 0


static func _instance_id_of(obj) -> int:
	return obj.get_instance_id() if obj != null and is_instance_valid(obj) else 0


static func _relation_label(rel: Relationship) -> String:
	if rel == null or not is_instance_valid(rel):
		return "<freed>"
	return type_name_of(rel.relation) if rel.relation != null else "*"


static func _target_label(rel: Relationship) -> String:
	if rel == null or not is_instance_valid(rel):
		return "<freed>"
	var target = rel.target
	if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
		return "<freed>"
	if target == null:
		return "*"
	if target is Entity:
		return "Entity " + String(target.name)
	if target is Component:
		return "Component " + type_name_of(target)
	if target is Script:
		return "Archetype " + script_label(target)
	return str(target)


static func _target_entity_id(rel: Relationship) -> int:
	if rel == null or not is_instance_valid(rel):
		return 0
	var target = rel.target
	if typeof(target) == TYPE_OBJECT and is_instance_valid(target) and target is Entity:
		return target.get_instance_id()
	return 0


static func _entity_path(entity: Entity) -> String:
	if entity == null or not is_instance_valid(entity):
		return "<freed>"
	return str(entity.get_path()) if entity.is_inside_tree() else String(entity.name)


static func _component_names(entity: Entity) -> Array:
	var names := []
	if entity == null or not is_instance_valid(entity):
		return names
	for comp in entity.components.values():
		names.append(type_name_of(comp))
	return names


## Display name of a scripted object: its class_name, else the script file name.
static func type_name_of(obj) -> String:
	if obj == null or (typeof(obj) == TYPE_OBJECT and not is_instance_valid(obj)):
		return "<freed>"
	if typeof(obj) != TYPE_OBJECT:
		return type_string(typeof(obj))
	var script = obj.get_script()
	if script != null:
		return script_label(script)
	return obj.get_class()


static func script_label(script: Script) -> String:
	if script == null:
		return "null"
	var global := String(script.get_global_name())
	if global != "":
		return global
	if script.resource_path != "":
		return script.resource_path.get_file().get_basename()
	return "Script#%d" % script.get_instance_id()


## Transport-safe, bounded rendering of a journaled value. Objects become
## labels (they may be freed before the message is encoded), containers are
## copied and capped, strings truncated.
static func encode_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			if not is_instance_valid(value):
				return "<freed>"
			if value is Entity:
				return "Entity %s#%d" % [String(value.name), value.get_instance_id()]
			if value is Node:
				return "%s(%s)" % [value.get_class(), String(value.name)]
			if value is Resource:
				return "%s#%d" % [type_name_of(value), value.get_instance_id()]
			return "%s#%d" % [value.get_class(), value.get_instance_id()]
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(value)
			return s if s.length() <= MAX_STRING else s.left(MAX_STRING) + "..."
		TYPE_ARRAY:
			if value.size() > MAX_CONTAINER:
				return "[...%d]" % value.size()
			var out := []
			for item in value:
				out.append(encode_value(item))
			return out
		TYPE_DICTIONARY:
			if value.size() > MAX_CONTAINER:
				return "{...%d}" % value.size()
			var out := {}
			for key in value:
				var k = key
				if typeof(key) == TYPE_OBJECT:
					k = encode_value(key)
				out[k] = encode_value(value[key])
			return out
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return str(value)
	return value


#endregion Resolution and labels
