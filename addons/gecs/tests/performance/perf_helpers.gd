## Simple performance timing helpers for GECS
## Records results to JSONL files (one JSON per line, one file per test)
class_name PerfHelpers


## Time a callable and return milliseconds
static func time_it(callable: Callable) -> float:
	var start_time = Time.get_ticks_usec()
	callable.call()
	var end_time = Time.get_ticks_usec()
	return (end_time - start_time) / 1000.0 # Return milliseconds


## Record performance result to test-specific JSONL file
static func record_result(test_name: String, scale: int, time_ms: float) -> void:
	var result = {
		"timestamp": Time.get_datetime_string_from_system(),
		"test": test_name,
		"scale": scale,
		"time_ms": time_ms,
		"godot_version": Engine.get_version_info().string
	}

	# Ensure perf directory exists
	var dir = DirAccess.open("res://")
	if dir:
		if not dir.dir_exists("reports"):
			dir.make_dir("reports")
		if not dir.dir_exists("reports/perf"):
			dir.make_dir("reports/perf")

	# Append to test-specific JSONL file (one JSON per line)
	var filepath = "res://reports/perf/%s.jsonl" % test_name
	# Check if file exists, if not create it with WRITE, otherwise open with READ_WRITE
	var file_exists = FileAccess.file_exists(filepath)
	var file = FileAccess.open(filepath, FileAccess.READ_WRITE if file_exists else FileAccess.WRITE)

	if file:
		if file_exists:
			file.seek_end()
		file.store_line(JSON.stringify(result))
		file.close()
	else:
		push_error("Failed to open performance log file: %s (Error: %s)" % [filepath, error_string(FileAccess.get_open_error())])

	# Print result for console visibility
	prints("📊 %s (scale=%d): %.2f ms" % [test_name, scale, time_ms])


## Optional: Assert performance threshold (simple version)
static func assert_threshold(time_ms: float, max_ms: float, message: String = "") -> void:
	if time_ms > max_ms:
		var error = "Performance threshold exceeded: %.2f ms > %.2f ms" % [time_ms, max_ms]
		if not message.is_empty():
			error = "%s - %s" % [message, error]
		assert(false, error)
