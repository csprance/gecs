## Performance timing helpers for GECS
## Records results to JSONL files (one JSON per line, one file per test)
##
## Two APIs:
## - time_it() + record_result(): single-shot timing (schema v1). Kept for
##   benchmarks whose state mutation makes re-running impractical.
## - bench(): warmup + repeated runs recording median/min/max/mean (schema v2).
##   Preferred for all new benchmarks — single-shot timings carry ±10-20% noise.
class_name PerfHelpers

static var _git_sha_cache: String = ""
static var _git_sha_resolved: bool = false


## Time a callable and return milliseconds
static func time_it(callable: Callable) -> float:
	var start_time = Time.get_ticks_usec()
	callable.call()
	var end_time = Time.get_ticks_usec()
	return (end_time - start_time) / 1000.0  # Return milliseconds


## Run a benchmark with warmup and repetition, record median-of-N (schema v2).
## [param callable] the timed operation.
## [param setup] optional untimed callable run before EVERY iteration (warmup and measured).
## [param teardown] optional untimed callable run after EVERY iteration.
## Use setup/teardown to recreate preconditions when the operation mutates state.
## Returns the recorded result dictionary.
static func bench(
	test_name: String,
	scale: int,
	callable: Callable,
	setup: Callable = Callable(),
	teardown: Callable = Callable(),
	warmup: int = 2,
	runs: int = 7,
	metadata: Dictionary = {},
) -> Dictionary:
	var times: Array[float] = []
	for i in range(warmup + runs):
		if setup.is_valid():
			setup.call()
		var start := Time.get_ticks_usec()
		callable.call()
		var elapsed := (Time.get_ticks_usec() - start) / 1000.0
		if teardown.is_valid():
			teardown.call()
		if i >= warmup:
			times.append(elapsed)
	return record_samples(test_name, scale, times, warmup, metadata)


## Record externally timed samples (including async frame-boundary measurements).
## Metadata describes the workload; raw samples allow later percentile analysis.
static func record_samples(
	test_name: String,
	scale: int,
	samples: Array[float],
	warmup: int = 0,
	metadata: Dictionary = {},
) -> Dictionary:
	assert(not samples.is_empty(), "A benchmark needs at least one measured sample")
	var times: Array[float] = samples.duplicate()
	times.sort()
	var n := times.size()
	var median: float = times[n / 2] if n % 2 == 1 else (times[n / 2 - 1] + times[n / 2]) / 2.0
	var mean := 0.0
	for t in times:
		mean += t
	mean /= n
	var result := {
		"timestamp": Time.get_datetime_string_from_system(),
		"test": test_name,
		"scale": scale,
		"schema": 2,
		"time_ms": median,  # median, kept under the v1 key so old plots keep working
		"median_ms": median,
		"min_ms": times[0],
		"max_ms": times[n - 1],
		"mean_ms": mean,
		"p95_ms": times[ceili(n * 0.95) - 1],
		"samples_ms": samples.duplicate(),
		"runs": n,
		"warmup": warmup,
		"godot_version": Engine.get_version_info().string,
		"git_sha": _git_sha(),
		"gecs_debug": ECS.debug,
		"debug_build": OS.is_debug_build(),
		"headless": DisplayServer.get_name() == "headless",
		"run_label": OS.get_environment("GECS_PERF_LABEL"),
		"workload": metadata,
	}
	_append_jsonl(test_name, result)
	prints(
		(
			"📊 %s (scale=%d): median %.2f ms  [min %.2f / max %.2f / mean %.2f, n=%d]"
			% [test_name, scale, median, times[0], times[n - 1], mean, n]
		)
	)
	return result


## Record a single-shot performance result (schema v1)
static func record_result(test_name: String, scale: int, time_ms: float) -> void:
	var result = {
		"timestamp": Time.get_datetime_string_from_system(),
		"test": test_name,
		"scale": scale,
		"time_ms": time_ms,
		"godot_version": Engine.get_version_info().string,
		"git_sha": _git_sha(),
	}
	_append_jsonl(test_name, result)
	prints("📊 %s (scale=%d): %.2f ms" % [test_name, scale, time_ms])


static func _append_jsonl(test_name: String, result: Dictionary) -> void:
	# Ensure perf directory exists
	var dir = DirAccess.open("res://")
	if dir:
		if not dir.dir_exists("reports"):
			dir.make_dir("reports")
		if not dir.dir_exists("reports/perf"):
			dir.make_dir("reports/perf")

	# Append to test-specific JSONL file (one JSON per line)
	var filepath = "res://reports/perf/%s.jsonl" % test_name
	var file_exists = FileAccess.file_exists(filepath)
	var file = FileAccess.open(filepath, FileAccess.READ_WRITE if file_exists else FileAccess.WRITE)

	if file:
		if file_exists:
			file.seek_end()
		file.store_line(JSON.stringify(result))
		file.close()
	else:
		push_error(
			(
				"Failed to open performance log file: %s (Error: %s)"
				% [filepath, error_string(FileAccess.get_open_error())]
			)
		)


## Best-effort short git sha for correlating results with code state
static func _git_sha() -> String:
	if _git_sha_resolved:
		return _git_sha_cache
	_git_sha_resolved = true
	var output := []
	var exit_code := OS.execute("git", ["rev-parse", "--short", "HEAD"], output)
	if exit_code == 0 and output.size() > 0:
		_git_sha_cache = str(output[0]).strip_edges()
	return _git_sha_cache


## Optional: Assert performance threshold (simple version)
static func assert_threshold(time_ms: float, max_ms: float, message: String = "") -> void:
	if time_ms > max_ms:
		var error = "Performance threshold exceeded: %.2f ms > %.2f ms" % [time_ms, max_ms]
		if not message.is_empty():
			error = "%s - %s" % [message, error]
		assert(false, error)
