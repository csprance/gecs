extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	# Defensively unregister any gecs/systems/* monitor that leaked from a failed test.
	# Each test is responsible for its own cleanup; this guards the suite against order-
	# dependent failures if a future assertion aborts before the monitor is removed.
	for sys_name in ["s_noop", "s_noop#2"]:
		var id: StringName = &"gecs/systems/%s" % sys_name
		if Performance.has_custom_monitor(id):
			Performance.remove_custom_monitor(id)
	world.purge(false)


func _monitor_id_for(system: System) -> StringName:
	return system._perf_monitor_id


func test_flag_off_by_default_registers_no_monitor():
	var s = NoOpSystem.new()
	world.add_system(s)
	world.process(0.016)
	assert_bool(s.performance_monitor).is_false()
	assert_str(String(_monitor_id_for(s))).is_equal("")


func test_flag_on_registers_monitor_and_returns_last_exec_time():
	var s = NoOpSystem.new()
	s.performance_monitor = true
	world.add_system(s)
	# Monitor is registered as soon as the system enters the tree + setup runs
	var id = _monitor_id_for(s)
	assert_str(String(id)).is_equal("gecs/systems/s_noop")
	assert_bool(Performance.has_custom_monitor(id)).is_true()
	# After one frame the callable should return current-frame time in seconds
	# (Godot's MONITOR_TYPE_TIME formatter converts to ms for display).
	world.process(0.016)
	var sample = Performance.get_custom_monitor(id)
	assert_float(sample).is_equal(s._last_execution_time_ms / 1000.0)
	assert_float(sample).is_greater_equal(0.0)


func test_flag_toggled_off_at_runtime_unregisters():
	var s = NoOpSystem.new()
	s.performance_monitor = true
	world.add_system(s)
	var id = _monitor_id_for(s)
	assert_bool(Performance.has_custom_monitor(id)).is_true()
	s.performance_monitor = false
	assert_bool(Performance.has_custom_monitor(id)).is_false()
	assert_str(String(_monitor_id_for(s))).is_equal("")


func test_flag_toggled_back_on_re_registers():
	var s = NoOpSystem.new()
	s.performance_monitor = true
	world.add_system(s)
	s.performance_monitor = false
	s.performance_monitor = true
	var id = _monitor_id_for(s)
	assert_bool(Performance.has_custom_monitor(id)).is_true()


func test_exit_tree_unregisters_monitor():
	# world.remove_system() calls queue_free() which is async, so we can't assert
	# unregistration synchronously through that path. Instead, attach the system
	# to a plain holder node we own — that gives us a synchronous remove_child →
	# _exit_tree → unregister — without leaking a freed node into the world's
	# systems_by_group (which would crash purge() during after_test).
	var holder = auto_free(Node.new())
	add_child(holder)
	var s = NoOpSystem.new()
	holder.add_child(s)
	# Setter runs with is_inside_tree() true → registers immediately.
	s.performance_monitor = true
	var id = _monitor_id_for(s)
	assert_bool(Performance.has_custom_monitor(id)).is_true()
	holder.remove_child(s)
	assert_bool(Performance.has_custom_monitor(id)).is_false()
	s.free()


func test_runtime_aggregates_min_max_avg_in_lastRunData():
	# Enable ECS.debug so _handle() populates lastRunData. The runtime-side
	# aggregator runs unconditionally when `measure_time` is true, and injects
	# min_ms/max_ms/avg_ms/sample_count so the UI doesn't need to aggregate.
	var prev_debug = ECS.debug
	ECS.debug = true
	var s = NoOpSystem.new()
	world.add_system(s)
	world.process(0.016)
	world.process(0.016)
	world.process(0.016)
	assert_int(s._metric_sample_count).is_equal(3)
	assert_float(s._metric_min_ms).is_greater_equal(0.0)
	assert_float(s._metric_max_ms).is_greater_equal(s._metric_min_ms)
	assert_float(s._metric_avg_ms).is_greater_equal(s._metric_min_ms)
	assert_float(s._metric_avg_ms).is_less_equal(s._metric_max_ms)
	# lastRunData carries the aggregated values for the UI
	assert_bool(s.lastRunData.has("min_ms")).is_true()
	assert_bool(s.lastRunData.has("max_ms")).is_true()
	assert_bool(s.lastRunData.has("avg_ms")).is_true()
	assert_int(s.lastRunData.get("sample_count", 0)).is_equal(3)
	ECS.debug = prev_debug


func test_reset_performance_metrics_clears_state():
	var prev_debug = ECS.debug
	ECS.debug = true
	var s = NoOpSystem.new()
	world.add_system(s)
	world.process(0.016)
	world.process(0.016)
	assert_int(s._metric_sample_count).is_equal(2)
	s.reset_performance_metrics()
	assert_int(s._metric_sample_count).is_equal(0)
	assert_float(s._metric_min_ms).is_equal(0.0)
	assert_float(s._metric_max_ms).is_equal(0.0)
	assert_float(s._metric_avg_ms).is_equal(0.0)
	# Next frame starts fresh — first sample becomes the new min AND max
	world.process(0.016)
	assert_int(s._metric_sample_count).is_equal(1)
	assert_float(s._metric_min_ms).is_equal(s._metric_max_ms)
	ECS.debug = prev_debug


func test_duplicate_script_gets_unique_suffix():
	var a = NoOpSystem.new()
	var b = NoOpSystem.new()
	a.performance_monitor = true
	b.performance_monitor = true
	world.add_system(a)
	world.add_system(b)
	var id_a = _monitor_id_for(a)
	var id_b = _monitor_id_for(b)
	assert_str(String(id_a)).is_equal("gecs/systems/s_noop")
	assert_str(String(id_b)).is_equal("gecs/systems/s_noop#2")
	assert_bool(Performance.has_custom_monitor(id_a)).is_true()
	assert_bool(Performance.has_custom_monitor(id_b)).is_true()
