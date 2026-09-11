extends GdUnitTestSuite
## Phase 2 subscription handshake, driven game-side through ECS._on_debugger_message
## (the editor->game control channel). The editor transport can't be exercised
## headlessly, so a test sink stands in for the editor and captures what the game
## would have sent.

var runner: GdUnitSceneRunner
var world: World

var _saved_attached: bool
var _saved_cache: int
var _saved_sink: Callable
var _saved_debug: bool
var _saved_tel: bool
var _saved_life: bool
var _saved_prop: bool

# Captured message names from the sink.
var _msgs: Array = []


class MetricSystem:
	extends System

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		pass


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func before_test():
	_saved_attached = GECSEditorDebuggerMessages.attached
	_saved_cache = GECSEditorDebuggerMessages._attached_cache
	_saved_sink = GECSEditorDebuggerMessages._test_sink
	_saved_debug = ECS.debug
	_saved_tel = GECSEditorDebuggerMessages.telemetry_active
	_saved_life = GECSEditorDebuggerMessages.lifecycle_active
	_saved_prop = GECSEditorDebuggerMessages.property_changes_active
	ECS.debug = true
	_msgs = []


func after_test():
	GECSEditorDebuggerMessages._test_sink = _saved_sink
	GECSEditorDebuggerMessages._attached_cache = _saved_cache
	GECSEditorDebuggerMessages.attached = _saved_attached
	GECSEditorDebuggerMessages.telemetry_active = _saved_tel
	GECSEditorDebuggerMessages.lifecycle_active = _saved_life
	GECSEditorDebuggerMessages.property_changes_active = _saved_prop
	ECS.debug = _saved_debug
	if world:
		world.purge(false)


func _install_sink() -> void:
	GECSEditorDebuggerMessages._test_sink = func(m, _d): _msgs.append(m)


func _subscribe(cats: Dictionary, hz: float = 10.0) -> void:
	ECS._on_debugger_message("subscribe", [cats, hz])


func test_subscribe_attaches_without_replaying_existing_world() -> void:
	var e := Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e, null, false)
	_install_sink()
	for i in 10: _subscribe({"system_metrics": true, "entity_lifecycle": true, "property_changes": true})
	assert_bool(GECSEditorDebuggerMessages.attached).is_true()
	assert_bool(GECSEditorDebuggerMessages.lifecycle_active).is_false()
	assert_array(_msgs).is_empty()


func test_unsubscribe_silences_everything() -> void:
	_install_sink()
	_subscribe({"system_metrics": true, "entity_lifecycle": true, "property_changes": true})
	ECS._on_debugger_message("unsubscribe", [])
	_msgs.clear()

	assert_bool(GECSEditorDebuggerMessages.attached).is_false()

	# Churn after unsubscribe must produce nothing.
	world.process(0.016)
	var e := Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e, null, false)
	world.remove_entity(e)

	assert_int(_msgs.size()).is_equal(0)


func test_structural_and_property_changes_never_push() -> void:
	# Lifecycle on, property changes off: adding a component still reports, but a
	# subsequent property write does not.
	_install_sink()
	_subscribe({"system_metrics": true, "entity_lifecycle": true, "property_changes": false})

	var e := Entity.new()
	var comp := C_TestA.new()
	e.add_component(comp)
	world.add_entity(e, null, false)
	assert_array(_msgs).is_empty()

	_msgs.clear()
	# Trigger a property change through the world callback path.
	if comp.has_signal("property_changed"):
		comp.property_changed.emit(comp, "value", 0, 1)
	assert_bool(_msgs.has(GECSEditorDebuggerMessages.Msg.COMPONENT_PROPERTY_CHANGED)).is_false()


func test_metrics_aggregate_without_pushes() -> void:
	var system := MetricSystem.new()
	world.add_system(system)
	var e := Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e, null, false)

	_install_sink()
	_subscribe({"system_metrics": true, "entity_lifecycle": true, "property_changes": true}, 10.0)
	_msgs.clear()

	# 10 frames of 0.03s = 0.3s of sim time. At the subscribed 10 Hz (0.1s) that is
	# ~2-3 telemetry samples, NOT one per frame.
	for i in 10:
		world.process(0.03)

	var samples := _msgs.count(GECSEditorDebuggerMessages.Msg.PROCESS_WORLD)
	assert_int(samples).is_equal(0)
	assert_int(system._metric_sample_count).is_greater(0)


func test_reset_system_metrics_is_forwarded_to_world() -> void:
	var system := MetricSystem.new()
	world.add_system(system)
	var e := Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e, null, false)
	# Accumulate at least one metric sample.
	world.process(0.016)
	world.process(0.016)
	assert_int(system._metric_sample_count).is_greater(0)

	# Forwarded through the ECS control channel to world._handle_debugger_message.
	ECS._on_debugger_message("reset_system_metrics", [])
	assert_int(system._metric_sample_count).is_equal(0)
