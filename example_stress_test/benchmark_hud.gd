extends Control
## Stress-test benchmark HUD.
##
## Tracks entity count, smoothed FPS, and the highest entity count sustained
## at each FPS threshold. Auto-stops the benchmark when the lowest threshold
## (default 15 FPS) is breached — freezes all systems and writes a final
## summary line to res://reports/perf/stress_test_ramp.jsonl for later graphing.

@export var spawner_path: NodePath
## FPS thresholds to track, highest first. The lowest one is the auto-stop
## trigger: once FPS sustains below it for [member sustain_seconds] seconds,
## all systems freeze and the final report is written.
@export var fps_thresholds: Array[float] = [60.0, 30.0, 15.0]
## FPS must stay at/above a threshold for this many seconds before it counts
## as "sustained" (ignores one-frame hitches).
@export var sustain_seconds: float = 1.0
## Crossing-event log (one line per threshold breach, appended across runs).
@export var log_path: String = "res://reports/perf/stress_test_ramp.jsonl"
## Test name written into the JSONL record so it plots alongside other perf
## tests that follow the same schema.
@export var test_name: String = "stress_test_ramp"

@onready var label: Label = $Label

var _spawner: SimpleRandomSpawnerSystem
# For each threshold: {"peak": int, "sustained_t": float, "below_t": float, "crossed_down": bool}
var _threshold_state: Array[Dictionary] = []
var _log_session_id: String = ""
var _benchmark_complete: bool = false
var _run_start_msec: int = 0


func _ready() -> void:
	if has_node(spawner_path):
		_spawner = get_node(spawner_path)
	for _t in fps_thresholds:
		_threshold_state.append(
			{"peak": 0, "sustained_t": 0.0, "below_t": 0.0, "crossed_down": false}
		)
	_log_session_id = Time.get_datetime_string_from_system().replace(":", "-")
	_run_start_msec = Time.get_ticks_msec()


func _process(delta: float) -> void:
	if _benchmark_complete:
		return

	var fps: float = Engine.get_frames_per_second()
	var entity_count := _entity_count()

	# Update every threshold; the last one also governs auto-stop.
	for i in fps_thresholds.size():
		var th: float = fps_thresholds[i]
		var state: Dictionary = _threshold_state[i]
		_update_threshold(state, th, fps, entity_count, delta)

	# Auto-stop: last threshold in the list breached past the sustain window.
	var last_idx: int = fps_thresholds.size() - 1
	if last_idx >= 0:
		var last_state: Dictionary = _threshold_state[last_idx]
		if (
			not _benchmark_complete
			and last_state.get("crossed_down", false)
			and float(last_state["below_t"]) >= sustain_seconds
		):
			_finalize_benchmark(fps, entity_count)
			return

	_render_live(fps, entity_count)


func _entity_count() -> int:
	if ECS.world == null:
		return 0
	return ECS.world.entities.size()


func _update_threshold(
	state: Dictionary, threshold: float, fps: float, entities: int, delta: float
) -> void:
	if fps >= threshold:
		state["below_t"] = 0.0
		state["sustained_t"] = state["sustained_t"] + delta
		if state["sustained_t"] >= sustain_seconds:
			if entities > int(state["peak"]):
				state["peak"] = entities
	else:
		state["sustained_t"] = 0.0
		state["below_t"] = state["below_t"] + delta
		# First-time crossing-down event — log it.
		if not state["crossed_down"] and int(state["peak"]) > 0:
			state["crossed_down"] = true
			_log_crossing(threshold, int(state["peak"]), fps, entities)


func _render_live(fps: float, entity_count: int) -> void:
	var lines := [
		"Entities: %d" % entity_count,
		"FPS:      %.1f" % fps,
	]
	if _spawner:
		(
			lines
			.append(
				(
					"Spawn:    %.1f/s  (ramp +%.2f/s, t=%.1fs)"
					% [
						_spawner.current_spawn_rate(),
						_spawner.ramp_per_second,
						_spawner.elapsed_time(),
					]
				)
			)
		)
	lines.append("")
	for i in fps_thresholds.size():
		var th: float = fps_thresholds[i]
		var state: Dictionary = _threshold_state[i]
		var peak := int(state["peak"])
		var marker: String = " (dropped)" if state["crossed_down"] else ""
		lines.append("Peak @ %d FPS: %d%s" % [int(th), peak, marker])
	label.text = "\n".join(lines)


# -- Auto-stop + final report --------------------------------------------


func _finalize_benchmark(final_fps: float, final_entities: int) -> void:
	_benchmark_complete = true
	var per_system_stats := _snapshot_system_stats()
	var run_duration_s: float = (Time.get_ticks_msec() - _run_start_msec) / 1000.0

	# Freeze everything — disable all systems so entities stop moving / spawning.
	_freeze_world()

	_write_final_report(final_fps, final_entities, per_system_stats, run_duration_s)
	_render_complete(final_fps, final_entities, per_system_stats, run_duration_s)


func _snapshot_system_stats() -> Array:
	var out: Array = []
	if ECS.world == null:
		return out
	for sys in ECS.world.systems:
		var sys_name := "unknown"
		var script: Script = sys.get_script()
		if script and script.resource_path:
			sys_name = script.resource_path.get_file().get_basename()
		(
			out
			.append(
				{
					"system": sys_name,
					"group": sys.group,
					"min_ms": sys._metric_min_ms,
					"max_ms": sys._metric_max_ms,
					"avg_ms": sys._metric_avg_ms,
					"samples": sys._metric_sample_count,
				}
			)
		)
	return out


func _freeze_world() -> void:
	if ECS.world == null:
		return
	for sys in ECS.world.systems:
		sys.active = false


func _write_final_report(
	final_fps: float,
	final_entities: int,
	per_system: Array,
	run_duration_s: float,
) -> void:
	var record := {
		"test": test_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"session": _log_session_id,
		"godot_version": Engine.get_version_info().get("string", ""),
		"event": "final",
		"run_duration_s": run_duration_s,
		"final_fps": final_fps,
		"final_entities": final_entities,
		"thresholds": _thresholds_summary(),
		"systems": per_system,
	}
	_append_jsonl(record)


func _thresholds_summary() -> Array:
	var out: Array = []
	for i in fps_thresholds.size():
		var state: Dictionary = _threshold_state[i]
		(
			out
			.append(
				{
					"fps": fps_thresholds[i],
					"peak_entities": int(state["peak"]),
					"dropped": bool(state["crossed_down"]),
				}
			)
		)
	return out


func _log_crossing(
	threshold: float, peak_entities: int, current_fps: float, current_entities: int
) -> void:
	_append_jsonl(
		{
			"test": test_name,
			"timestamp": Time.get_datetime_string_from_system(),
			"session": _log_session_id,
			"godot_version": Engine.get_version_info().get("string", ""),
			"event": "crossing",
			"threshold_fps": threshold,
			"peak_entities_at_threshold": peak_entities,
			"fps_at_crossing": current_fps,
			"entities_at_crossing": current_entities,
		}
	)


func _append_jsonl(record: Dictionary) -> void:
	# Make sure the directory exists. DirAccess.make_dir_recursive_absolute
	# handles nested paths and is a no-op if it already exists.
	var dir_path: String = log_path.get_base_dir()
	if dir_path != "":
		DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f == null:
		push_warning("benchmark_hud: could not open log file at %s" % log_path)
		return
	f.seek_end()
	f.store_line(JSON.stringify(record))
	f.close()


func _render_complete(
	final_fps: float,
	final_entities: int,
	per_system: Array,
	run_duration_s: float,
) -> void:
	var lines: Array[String] = [
		"=== BENCHMARK COMPLETE ===",
		"",
		"Duration:    %.1f s" % run_duration_s,
		"Entities:    %d" % final_entities,
		"FPS @ stop:  %.1f" % final_fps,
		"",
	]
	for i in fps_thresholds.size():
		var state: Dictionary = _threshold_state[i]
		lines.append("Peak @ %d FPS: %d" % [int(fps_thresholds[i]), int(state["peak"])])
	lines.append("")
	lines.append("Per-system (ms):")
	for entry in per_system:
		(
			lines
			.append(
				(
					"  %-28s min=%.3f  max=%.3f  avg=%.3f  (n=%d)"
					% [
						entry["system"],
						entry["min_ms"],
						entry["max_ms"],
						entry["avg_ms"],
						entry["samples"],
					]
				)
			)
		)
	lines.append("")
	lines.append("Logged → %s" % log_path)
	label.text = "\n".join(lines)
