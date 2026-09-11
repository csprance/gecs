@tool
class_name GECSExplorerModel
extends RefCounted
## Editor session state shared by main workspace, compact debugger and detached views.
signal updated(kind: String, data: Dictionary)
signal request_finished(op: String, result: Dictionary, context: Dictionary)

const Codec = preload("res://addons/gecs/debug/explorer/gecs_explorer_codec.gd")
const MAX_SAMPLES := 600
var sender: Callable
var session_id := 0
var connected := false
var ended_at := ""
var world_path := ""
var script_breaked := false
var world_id := 0
var epoch := 0
var catalogue: Array = []
var step_state: Dictionary = {}
var entities: Dictionary = {}
var snapshots: Dictionary = {}
var watches: Dictionary = {}
var series: Dictionary = {}
var changes: Array = []
var captures: Array = []
var _next_request := 1
var _pending: Dictionary = {}
var _latest: Dictionary = {}
var _sequence := 0
var graph_ids: Dictionary = {}
var _next_graph := 100000
var watch_users: Dictionary = {}

func allocate_graph() -> int:
	var id := _next_graph
	_next_graph += 1
	graph_ids[id] = true
	return id

const VERSION := 2
const REQUEST_TIMEOUT_MS := 3000
const MAX_AUTO_READS := 4
const READ_OPS := ["hello", "systems", "sample", "graph", "debugger_state", "overview", "query", "inspect", "resolve_saved", "snapshot_export", "snapshot_preview", "capture"]
var clock: Callable = func(): return Time.get_ticks_msec()
var poll_provider: Callable
var _poll_times: Dictionary = {}
var _retry_at := 0
var _retry_delay := 1000
var _last_tick := -1
var _was_breaked := false
var _log_after := 0
var protocol_error := ""

func _now() -> int:
	return int(clock.call())

func _key(op: String, context: Dictionary) -> String:
	return op + ":" + str(context.get("key", op))

func has_pending(op: String, context: Dictionary = {}) -> bool:
	var key := _key(op, context)
	for pending in _pending.values():
		if pending.key == key: return true
	return false

func request(op: String, args: Dictionary = {}, context: Dictionary = {}) -> int:
	if not connected or script_breaked or not protocol_error.is_empty() or not sender.is_valid() or (op != "hello" and world_id == 0): return 0
	var key := _key(op, context)
	# Automatic polling is single-flight. Explicit reads use latest-result wins.
	if context.get("automatic", false) and has_pending(op, context): return 0
	var id := _next_request
	_next_request += 1
	_pending[id] = {"op": op, "context": context.duplicate(true), "key": key, "sent": _now(), "world": world_id, "epoch": epoch}
	_latest[key] = id
	var wire_args := args.duplicate(true)
	if op in ["sample", "debugger_state", "capture"]:
		# An authoritative definition set repairs lost watch/unwatch commands.
		wire_args["watch_definitions"] = watches.values().duplicate(true)
	var sent = sender.call("gecs:explorer_request", [{"version": VERSION, "request_id": id, "op": op, "world": world_id, "epoch": epoch, "args": wire_args}])
	if sent is bool and not sent:
		_finish_error(id, "Debugger transport unavailable")
		return 0
	return id

func _finish_error(id: int, error: String) -> void:
	if not _pending.has(id): return
	var pending: Dictionary = _pending[id]
	_pending.erase(id)
	# A superseded read must not replace a newer successful result with an error.
	if pending.op in READ_OPS and id != _latest.get(pending.key): return
	var mutation: bool = pending.op not in READ_OPS and pending.op not in ["watch", "unwatch"]
	request_finished.emit(pending.op, {"error": error + ("; outcome unknown. Inspect current state before trying again." if mutation else ""), "outcome_unknown": mutation}, pending.context)
	if mutation: refresh()

func _cancel_pending(reason: String) -> void:
	for id in _pending.keys(): _finish_error(id, reason)
	_latest.clear()

func refresh() -> void:
	_poll_times.clear()

## Called by the editor plugin even when the debugger dock is inactive.
## Clock injection makes loss, timeout and pause behavior deterministic in tests.
func tick() -> void:
	var now := _now()
	var elapsed := maxi(0, now - _last_tick) if _last_tick >= 0 else 0
	_last_tick = now
	if not connected: return
	if script_breaked or _was_breaked:
		for pending in _pending.values(): pending.sent += elapsed
		_retry_at += elapsed
		if not script_breaked: refresh()
		_was_breaked = script_breaked
		return
	for id in _pending.keys():
		if now - int(_pending[id].sent) >= REQUEST_TIMEOUT_MS:
			_finish_error(id, "Request timed out")
	if not protocol_error.is_empty(): return
	if world_id == 0:
		if now >= _retry_at and not has_pending("hello"):
			sender.call("gecs:subscribe", [])
			request("hello", {}, {"automatic": true})
			_retry_at = now + _retry_delay
			_retry_delay = mini(5000, _retry_delay * 2)
		return
	var polls: Array = poll_provider.call() if poll_provider.is_valid() else []
	polls.append({"op": "debugger_state", "args": {"after": _log_after}, "interval": 2000})
	# Oldest-served first: a constantly visible panel cannot starve another one.
	polls.sort_custom(func(a, b): return int(_poll_times.get(_key(a.op, a.get("context", {})), -1)) < int(_poll_times.get(_key(b.op, b.get("context", {})), -1)))
	var in_flight := 0
	for pending in _pending.values():
		if pending.context.get("automatic", false): in_flight += 1
	for poll in polls:
		if in_flight >= MAX_AUTO_READS: break
		var context: Dictionary = poll.get("context", {}).duplicate()
		context["automatic"] = true
		var key := _key(poll.op, context)
		if has_pending(poll.op, context): continue
		if _poll_times.has(key) and now - int(_poll_times[key]) < int(poll.get("interval", 500)): continue
		_poll_times[key] = now
		if request(poll.op, poll.get("args", {}), context) != 0: in_flight += 1

func accept(payload: Dictionary) -> void:
	var id := int(payload.get("request_id", 0))
	if not _pending.has(id): return
	var pending: Dictionary = _pending[id]
	if not script_breaked and not _was_breaked and _now() - int(pending.sent) >= REQUEST_TIMEOUT_MS:
		_finish_error(id, "Request timed out")
		return
	var result: Dictionary = payload.get("result", {})
	if payload.get("version", VERSION) != VERSION or result.get("code") == "protocol_mismatch":
		protocol_error = "Incompatible GECS Explorer protocol; update the editor and game together"
		_cancel_pending(protocol_error)
		updated.emit("connection_error", {"error": protocol_error})
		return
	if payload.get("op", pending.op) != pending.op:
		_finish_error(id, "Unexpected response operation")
		return
	if result.get("code") == "world_changed":
		invalidate_world()
		return
	_pending.erase(id)
	if pending.op == "hello":
		if id != _latest.get(pending.key): return
		if result.has("error"):
			request_finished.emit(pending.op, result, pending.context)
			return
		var changed_world: bool = world_id != payload.world or epoch != payload.epoch
		if changed_world:
			_cancel_pending("World changed")
			entities.clear()
			captures.clear()
			watch_users.clear()
			snapshots.clear()
			watches.clear()
			series.clear()
			_sequence = 0
			_log_after = 0
		world_id = payload.world
		epoch = payload.epoch
		catalogue = result.get("catalogue", [])
		ended_at = ""
		world_path = str(result.get("world_path", "World"))
		_retry_delay = 1000
		var preferred: int = step_state.get("preferred_kind", 2)
		step_state = result.get("step_state", {}).duplicate(true)
		step_state["preferred_kind"] = preferred
		if changed_world: updated.emit("world_changed", {})
		refresh()
		updated.emit("hello", result)
	elif payload.get("world") != world_id or payload.get("epoch") != epoch:
		# A new runtime world can answer an old-world request. Re-handshake.
		request_finished.emit(pending.op, {"error": "World changed"}, pending.context)
		invalidate_world()
		return
	if pending.op in READ_OPS and pending.op != "hello" and id != _latest.get(pending.key): return
	if not result.has("error"):
		match pending.op:
			"inspect":
				if result.has("identity"): snapshots[int(result.identity.iid)] = result
			"capture":
				captures.append(result)
				if captures.size() > 10: captures.pop_front()
			"systems": updated.emit("systems", result.get("systems", {}))
			"sample": _accept_sample(result)
			"graph": updated.emit("graph", result)
			"debugger_state":
				var preferred: int = step_state.get("preferred_kind", 2)
				var next: Dictionary = result.get("step_state", {}).duplicate(true)
				next["preferred_kind"] = preferred
				if step_state != next:
					step_state = next
					updated.emit("step", step_state)
				if result.get("gap", false) or not result.get("omitted", []).is_empty(): updated.emit("history_gap", result)
				for log in result.get("logs", []): updated.emit("log", log)
				_log_after = int(result.get("after", _log_after))
				updated.emit("run", result.get("run_result", {}).merged({"running": not result.get("run", {}).is_empty()}))
				if result.get("more", false): _poll_times.erase(_key("debugger_state", {}))
		if pending.op not in READ_OPS: refresh()
	request_finished.emit(pending.op, result, pending.context)

func _accept_sample(data: Dictionary) -> void:
	for key in data.get("samples", {}):
		if not watches.has(key): continue
		var snapshot: Dictionary = data.samples[key]
		if snapshot.has("identity"): snapshots[int(snapshot.identity.iid)] = snapshot
		if not series.has(key): series[key] = []
		if not series[key].is_empty() and int(data.time) - int(series[key].back().time) > 1500:
			series[key].append({"time": int(data.time) - 1, "step": data.step, "data": {}})
		series[key].append({"time": data.time, "step": data.step, "data": chart_sample(snapshot)})
		while series[key].size() > MAX_SAMPLES: series[key].pop_front()
	updated.emit("sample", data)

func event(payload: Dictionary) -> void:
	if payload.get("world") != world_id or payload.get("epoch") != epoch: return
	if int(payload.get("sequence", 0)) <= _sequence: return
	_sequence = payload.sequence
	var kind := str(payload.get("kind", ""))
	var data: Dictionary = payload.get("data", {})
	if kind == "state_changed":
		refresh()
	elif kind in ["edit", "scratchpad"]:
		changes.append({"kind": kind, "data": data})
		if changes.size() > 200: changes.pop_front()
	updated.emit(kind, data)

func disconnect_session() -> void:
	ended_at = Time.get_datetime_string_from_system(false, true)
	connected = false
	world_id = 0
	epoch = 0
	_cancel_pending("Session ended")
	protocol_error = ""
	_retry_at = 0
	_retry_delay = 1000
	_last_tick = -1
	_was_breaked = false
	watches.clear()
	updated.emit("disconnected", {})

func watch(ref: Dictionary, key: String) -> void:
	watch_users[key] = int(watch_users.get(key, 0)) + 1
	if watches.has(key): return
	watches[key] = {"entity": ref, "key": key}
	request("watch", watches[key])

func unwatch(key: String) -> void:
	watch_users[key] = maxi(0, int(watch_users.get(key, 0)) - 1)
	if watch_users[key] > 0: return
	watches.erase(key)
	series.erase(key)
	watch_users.erase(key)
	request("unwatch", {"key": key})

func reveal(ref: Dictionary) -> void:
	if connected and ref.get("world") == world_id and ref.get("epoch") == epoch and sender.is_valid():
		sender.call("scene:request_scene_tree", [])
		sender.call("scene:inspect_objects", [[int(ref.iid)], true])

static func compare(before: Dictionary, after: Dictionary) -> Array:
	var rows: Array = []
	var left: Dictionary = before.get("entities", {})
	var right: Dictionary = after.get("entities", {})
	for id in left:
		if not right.has(id): rows.append({"entity": id, "field": "Entity", "before": "Present", "after": "Removed"})
	for id in right:
		if not left.has(id):
			rows.append({"entity": id, "field": "Entity", "before": "Absent", "after": "Added"})
			continue
		var a := _flatten(left[id])
		var b := _flatten(right[id])
		var keys := a.keys()
		for key in b:
			if not keys.has(key): keys.append(key)
		for key in keys:
			if a.get(key) != b.get(key): rows.append({"entity": id, "field": key, "before": a.get(key, "Absent"), "after": b.get(key, "Absent")})
	var memberships: Dictionary = before.get("memberships", {})
	var next: Dictionary = after.get("memberships", {})
	var queries := memberships.keys()
	for key in next:
		if not queries.has(key): queries.append(key)
	for key in queries:
		if memberships.get(key, []) != next.get(key, []): rows.append({"entity": "Query", "field": key, "before": str(memberships.get(key, [])), "after": str(next.get(key, []))})
	return rows

static func _flatten(snapshot: Dictionary) -> Dictionary:
	var values := {"Enabled": str(snapshot.get("enabled", false))}
	for comp in snapshot.get("components", []):
		values[comp.script] = "Present"
		for field in comp.fields: values[comp.script + ":" + field.name] = field.value
	for rel in snapshot.get("relationships", []): values["Relationship " + str(rel.iid)] = rel
	for rel in snapshot.get("incoming_relationships", []): values["Incoming relationship " + str(rel.source.iid) + "/" + str(rel.iid)] = rel
	return values

func invalidate_world() -> void:
	world_id = 0
	epoch = 0
	_cancel_pending("World changed")
	_retry_at = 0
	_retry_delay = 1000
	_log_after = 0
	refresh()
	entities.clear()
	snapshots.clear()
	series.clear()
	captures.clear()
	updated.emit("world_changed", {})

## History contains chart channels, never 600 copies of all strings/resources.
static func chart_sample(snapshot: Dictionary) -> Dictionary:
	var result := {"components": [], "total": snapshot.get("total", 0)}
	if snapshot.has("error"): result["error"] = snapshot.error
	var count := 0
	for component in snapshot.get("components", []):
		var fields: Array = []
		for field in component.fields:
			if count >= 128: break
			if field.value.get("type") in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I]:
				fields.append({"name": field.name, "value": field.value})
				count += 1
		if not fields.is_empty(): result.components.append({"iid": component.iid, "fields": fields})
	return result
