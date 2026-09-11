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

func request(op: String, args: Dictionary = {}, context: Dictionary = {}) -> int:
	if not connected or not sender.is_valid() or (op != "hello" and world_id == 0): return 0
	var id := _next_request
	_next_request += 1
	_pending[id] = {"op": op, "context": context}
	var key := str(context.get("key", op))
	_latest[key] = id
	sender.call("gecs:explorer_request", [{"version": 1, "request_id": id, "op": op, "world": world_id, "epoch": epoch, "args": args}])
	return id

func accept(payload: Dictionary) -> void:
	var id := int(payload.get("request_id", 0))
	if payload.get("version", 1) != 1 or not _pending.has(id): return
	var pending: Dictionary = _pending[id]
	_pending.erase(id)
	if payload.get("op", pending.op) != pending.op: return
	var result: Dictionary = payload.get("result", {})
	if pending.op == "hello":
		if id != _latest.get("hello"): return
		var changed_world: bool = world_id != payload.world or epoch != payload.epoch
		world_id = payload.world
		epoch = payload.epoch
		catalogue = result.get("catalogue", [])
		ended_at = ""
		world_path = str(result.get("world_path", "World"))
		if changed_world:
			entities.clear()
			captures.clear()
			watch_users.clear()
			updated.emit("world_changed", {})
			snapshots.clear()
			watches.clear()
			series.clear()
			_sequence = 0
		var preferred: int = step_state.get("preferred_kind", 2)
		if result.get("step_state") is Dictionary:
			step_state = result.step_state.duplicate(true)
		elif changed_world:
			step_state = {} # Older runtimes may omit initial ECS state.
		step_state["preferred_kind"] = preferred
		updated.emit("hello", result)
	elif payload.get("world") != world_id or payload.get("epoch") != epoch:
		return
	var key := str(pending.context.get("key", pending.op))
	if pending.op in ["query", "inspect", "snapshot_export", "snapshot_preview", "overview"] and id != _latest.get(key): return
	if pending.op == "inspect" and result.has("identity"):
		snapshots[int(result.identity.iid)] = result
	if pending.op == "capture" and not result.has("error"):
		captures.append(result)
		if captures.size() > 10: captures.pop_front()
	request_finished.emit(pending.op, result, pending.context)

func event(payload: Dictionary) -> void:
	if payload.get("world") != world_id or payload.get("epoch") != epoch: return
	if int(payload.get("sequence", 0)) <= _sequence: return
	_sequence = payload.sequence
	var kind := str(payload.get("kind", ""))
	var data: Dictionary = payload.get("data", {})
	if kind == "sample":
		for key in data.get("samples", {}):
			var snapshot: Dictionary = data.samples[key]
			if snapshot.has("identity"): snapshots[int(snapshot.identity.iid)] = snapshot
			if not series.has(key): series[key] = []
			series[key].append({"time": data.time, "step": data.step, "data": chart_sample(snapshot)})
			if series[key].size() > MAX_SAMPLES: series[key].pop_front()
	elif kind in ["edit", "scratchpad"]:
		changes.append({"kind": kind, "data": data})
		if changes.size() > 200: changes.pop_front()
	updated.emit(kind, data)

func disconnect_session() -> void:
	ended_at = Time.get_datetime_string_from_system(false, true)
	connected = false
	world_id = 0
	epoch = 0
	_pending.clear()
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
	_pending.clear()
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
