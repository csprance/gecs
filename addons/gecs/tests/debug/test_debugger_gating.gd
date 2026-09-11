extends GdUnitTestSuite
## Phase 1 attach-gating: with debug_mode on but no debugger session, the runtime
## must build no debugger payloads and send nothing. When a session (here a test
## sink) is attached, the same operations must produce messages again.

var runner: GdUnitSceneRunner
var world: World

# Saved static state so this suite can't leak the attach flag into other suites
# (notably the perf benchmarks, which assume the real unattached path). ECS.debug
# is a process-wide flag other suites toggle, so pin it explicitly here too.
var _saved_attached: bool
var _saved_cache: int
var _saved_sink: Callable
var _saved_debug: bool


class NoMatchSystem:
	extends System

	func query() -> QueryBuilder:
		return q.with_all([C_TestD])

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
	# These tests assert on debug-mode behavior; pin the flag regardless of what
	# a previously-run suite left it at.
	ECS.debug = true


func after_test():
	# Restore process-wide state before the next suite runs.
	GECSEditorDebuggerMessages._test_sink = _saved_sink
	GECSEditorDebuggerMessages._attached_cache = _saved_cache
	GECSEditorDebuggerMessages.attached = _saved_attached
	ECS.debug = _saved_debug
	if world:
		world.purge(false)


## Exercise one process() plus a churn of structural changes. Uses a delta past the
## default telemetry sample interval (0.1s) so a telemetry sample fires when attached.
func _churn(system: System) -> void:
	world.add_system(system)
	world.process(0.2)
	var e := Entity.new()
	e.add_component(C_TestA.new())
	world.add_entity(e, null, false)
	world.process(0.2)
	world.remove_entity(e)


func test_unattached_builds_and_sends_nothing() -> void:
	# A sink is installed but the attach flags are forced OFF, so both the call-site
	# gate and can_send_message() must suppress every build and send.
	var count := [0]
	GECSEditorDebuggerMessages._test_sink = func(_m, _d): count[0] += 1
	GECSEditorDebuggerMessages._attached_cache = 0
	GECSEditorDebuggerMessages.attached = false

	var system := NoMatchSystem.new()
	_churn(system)

	# No debugger payloads leave the game while unattached.
	assert_int(count[0]).is_equal(0)
	# lastRunData building is a separate ECS.debug feature (not attach-gated), so it
	# is still populated for user code — it just never gets sent.
	assert_bool(system.lastRunData.is_empty()).is_false()


func test_attached_churn_produces_no_unsolicited_messages() -> void:
	var seen := {}
	GECSEditorDebuggerMessages._test_sink = func(m, _d): seen[m] = true
	GECSEditorDebuggerMessages.refresh_attached()  # sink valid -> attached == true

	assert_bool(GECSEditorDebuggerMessages.attached).is_true()

	var system := NoMatchSystem.new()
	_churn(system)

	assert_dict(seen).is_empty()
	assert_bool(system.lastRunData.is_empty()).is_false()
