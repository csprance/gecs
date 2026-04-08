extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


#region SystemTimer Unit Tests

func test_timer_does_not_tick_before_interval():
	var timer = SystemTimer.new()
	timer.interval = 1.0
	timer.advance(0.5)
	assert_bool(timer.ticked).is_false()
	assert_int(timer.tick_count).is_equal(0)


func test_timer_ticks_at_interval():
	var timer = SystemTimer.new()
	timer.interval = 1.0
	timer.advance(1.0)
	assert_bool(timer.ticked).is_true()
	assert_int(timer.tick_count).is_equal(1)


func test_timer_ticks_past_interval():
	var timer = SystemTimer.new()
	timer.interval = 1.0
	timer.advance(1.5)
	assert_bool(timer.ticked).is_true()
	assert_int(timer.tick_count).is_equal(1)
	# Overshoot carried forward
	assert_float(timer.time_elapsed).is_equal_approx(0.5, 0.001)


func test_timer_repeats():
	var timer = SystemTimer.new()
	timer.interval = 0.5
	# First tick
	timer.advance(0.5)
	assert_bool(timer.ticked).is_true()
	assert_int(timer.tick_count).is_equal(1)
	# Not enough for second tick
	timer.advance(0.3)
	assert_bool(timer.ticked).is_false()
	assert_int(timer.tick_count).is_equal(1)
	# Second tick
	timer.advance(0.2)
	assert_bool(timer.ticked).is_true()
	assert_int(timer.tick_count).is_equal(2)


func test_single_shot_deactivates():
	var timer = SystemTimer.new()
	timer.interval = 0.5
	timer.single_shot = true
	# First tick fires
	timer.advance(0.5)
	assert_bool(timer.ticked).is_true()
	assert_bool(timer.active).is_false()
	# Second advance does nothing
	timer.advance(0.5)
	assert_bool(timer.ticked).is_false()
	assert_int(timer.tick_count).is_equal(1)


func test_inactive_timer_does_not_advance():
	var timer = SystemTimer.new()
	timer.interval = 0.5
	timer.active = false
	timer.advance(1.0)
	assert_bool(timer.ticked).is_false()
	assert_float(timer.time_elapsed).is_equal(0.0)


func test_reset():
	var timer = SystemTimer.new()
	timer.interval = 0.5
	timer.advance(0.5)
	assert_int(timer.tick_count).is_equal(1)
	timer.reset()
	assert_float(timer.time_elapsed).is_equal(0.0)
	assert_int(timer.tick_count).is_equal(0)
	assert_bool(timer.ticked).is_false()
	assert_bool(timer.active).is_true()


func test_ticked_resets_each_advance():
	var timer = SystemTimer.new()
	timer.interval = 1.0
	timer.advance(1.0)
	assert_bool(timer.ticked).is_true()
	# Next advance below interval — ticked must be false
	timer.advance(0.1)
	assert_bool(timer.ticked).is_false()

#endregion SystemTimer Unit Tests


#region System + Timer Integration Tests

func test_system_without_timer_runs_every_frame():
	var sys = STimerTest.new()
	world.add_system(sys)
	world.process(0.016)
	world.process(0.016)
	world.process(0.016)
	assert_int(sys.run_count).is_equal(3)


func test_system_with_timer_skips_non_tick_frames():
	var sys = STimerTest.new()
	sys.set_tick_rate(1.0)
	world.add_system(sys)
	# 4 frames at 0.25s = 1.0s total (0.25 is exact in binary float)
	for i in 3:
		world.process(0.25)
	assert_int(sys.run_count).is_equal(0)
	world.process(0.25)
	assert_int(sys.run_count).is_equal(1)


func test_shared_timer_synchronizes_systems():
	var sys_a = STimerTest.new()
	var sys_b = STimerTest.new()
	var timer = sys_a.set_tick_rate(0.5)
	sys_b.tick_source = timer
	world.add_system(sys_a)
	world.add_system(sys_b)
	# Not enough time
	world.process(0.3)
	assert_int(sys_a.run_count).is_equal(0)
	assert_int(sys_b.run_count).is_equal(0)
	# Now enough
	world.process(0.2)
	assert_int(sys_a.run_count).is_equal(1)
	assert_int(sys_b.run_count).is_equal(1)
	# Both skip together
	world.process(0.1)
	assert_int(sys_a.run_count).is_equal(1)
	assert_int(sys_b.run_count).is_equal(1)


func test_paused_system_does_not_run_even_on_tick():
	var sys = STimerTest.new()
	sys.set_tick_rate(0.5)
	sys.paused = true
	world.add_system(sys)
	world.process(0.5)
	assert_int(sys.run_count).is_equal(0)


func test_single_shot_system_runs_once():
	var sys = STimerTest.new()
	sys.set_tick_rate(0.5, true)
	world.add_system(sys)
	world.process(0.5)
	assert_int(sys.run_count).is_equal(1)
	world.process(0.5)
	assert_int(sys.run_count).is_equal(1)
	world.process(0.5)
	assert_int(sys.run_count).is_equal(1)


func test_set_tick_rate_returns_timer():
	var sys = STimerTest.new()
	var timer = sys.set_tick_rate(0.25)
	assert_object(timer).is_not_null()
	assert_float(timer.interval).is_equal(0.25)
	assert_bool(timer.single_shot).is_false()
	assert_object(sys.tick_source).is_same(timer)


func test_set_tick_rate_single_shot():
	var sys = STimerTest.new()
	var timer = sys.set_tick_rate(2.0, true)
	assert_float(timer.interval).is_equal(2.0)
	assert_bool(timer.single_shot).is_true()


func test_system_with_timer_in_group():
	var sys = STimerTest.new()
	sys.group = "physics"
	sys.set_tick_rate(0.5)
	world.add_system(sys)
	# Process physics group — timer should advance
	world.process(0.3, "physics")
	assert_int(sys.run_count).is_equal(0)
	world.process(0.2, "physics")
	assert_int(sys.run_count).is_equal(1)


func test_timer_overshoot_prevents_drift():
	var sys = STimerTest.new()
	sys.set_tick_rate(0.5)
	world.add_system(sys)
	# Large delta overshoots by 0.1
	world.process(0.6)
	assert_int(sys.run_count).is_equal(1)
	# Only 0.4 more needed (0.1 carried + 0.4 = 0.5)
	world.process(0.4)
	assert_int(sys.run_count).is_equal(2)

func test_subsystem_timer_gates_execution():
	# Create a system with two subsystems — one timed, one not
	var sys = SubsystemTimerTestSystem.new()
	world.add_system(sys)
	# Entity needed so subsystems have something to process
	var entity = Entity.new()
	entity.add_component(C_TestA.new())
	entity.add_component(C_TestB.new())
	world.add_entity(entity)

	# First frame: untimed subsystem runs, timed (0.5s) does not
	world.process(0.1)
	assert_int(sys.always_count).is_equal(1)
	assert_int(sys.timed_count).is_equal(0)

	# Accumulate to 0.5s total
	world.process(0.1)
	world.process(0.1)
	world.process(0.1)
	world.process(0.1)
	assert_int(sys.always_count).is_equal(5)
	assert_int(sys.timed_count).is_equal(1)

	# One more frame — timed resets, doesn't fire yet
	world.process(0.1)
	assert_int(sys.always_count).is_equal(6)
	assert_int(sys.timed_count).is_equal(1)

#endregion System + Timer Integration Tests


#region Subsystem Timer Test Helper

class SubsystemTimerTestSystem extends System:
	var always_count: int = 0
	var timed_count: int = 0
	var _timer: SystemTimer

	func setup():
		process_empty = true
		_timer = SystemTimer.new()
		_timer.interval = 0.5

	func sub_systems() -> Array[Array]:
		return [
			[q.with_all([C_TestA]), _process_always],
			[q.with_all([C_TestB]), _process_timed, _timer],
		]

	func _process_always(_entities: Array[Entity], _components: Array, _delta: float):
		always_count += 1

	func _process_timed(_entities: Array[Entity], _components: Array, _delta: float):
		timed_count += 1

#endregion Subsystem Timer Test Helper
