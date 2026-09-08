## Step debugger: FRAME granularity = one main-loop iteration, detected through
## the injectable frame id provider (Engine.get_process_frames does not advance
## in a headless test).
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var _completed: Array = []
var _frame: Array = [0]


class CounterSystem:
	extends System
	var runs := 0

	func _init(group_name: String) -> void:
		group = group_name
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		runs += 1


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func before_test():
	_completed = []
	_frame = [0]
	world.step_completed.connect(_on_step_completed)
	world.debug_stepper().frame_id_provider = func(): return _frame[0]


func after_test():
	if world:
		if world.step_completed.is_connected(_on_step_completed):
			world.step_completed.disconnect(_on_step_completed)
		world.purge(false)
		# Purged systems are queue_freed; let that settle so the next test's
		# same-named systems do not collide with nodes pending deletion.
		await get_tree().process_frame


func _on_step_completed(_kind: int, info: Dictionary) -> void:
	_completed.append(info)


func _systems() -> Array:
	var phys := CounterSystem.new("physics")
	phys.name = "Phys"
	var rend := CounterSystem.new("render")
	rend.name = "Rend"
	world.add_system(phys)
	world.add_system(rend)
	return [phys, rend]


## One game iteration: bump the frame id, then the two group calls.
func _iterate(delta: float = 0.016) -> void:
	_frame[0] += 1
	world.process(delta, "physics")
	world.process(delta, "render")


func test_frame_step_waits_for_iteration_boundary_then_runs_every_group():
	var s := _systems()
	world.debug_pause()
	_iterate()  # settling iteration

	world.debug_step(GECSStepper.Kind.FRAME)
	# Same iteration id as the settling call: nothing may start mid-iteration.
	world.process(0.016, "physics")
	assert_int(s[0].runs).is_equal(0)

	_iterate()
	assert_array([s[0].runs, s[1].runs]).is_equal([1, 1])
	assert_int(_completed.size()).is_equal(0)
	assert_bool(world.debug_step_state().frame_step_active).is_true()

	_iterate()
	assert_int(_completed.size()).is_equal(1)
	assert_array([s[0].runs, s[1].runs]).is_equal([1, 1])
	assert_int(_completed[0].kind).is_equal(GECSStepper.Kind.FRAME)
	assert_array(_completed[0].systems).is_equal(["Phys", "Rend"])
	assert_bool(world.debug_step_state().frame_step_active).is_false()


func test_frame_step_count_two_runs_consecutive_iterations():
	var s := _systems()
	world.debug_pause()
	_iterate()

	world.debug_step(GECSStepper.Kind.FRAME, 2)
	_iterate()
	assert_array([s[0].runs, s[1].runs]).is_equal([1, 1])
	_iterate()
	assert_array([s[0].runs, s[1].runs]).is_equal([2, 2])
	assert_int(_completed.size()).is_equal(1)
	_iterate()
	assert_array([s[0].runs, s[1].runs]).is_equal([2, 2])
	assert_int(_completed.size()).is_equal(2)


func test_frame_step_from_mid_group_finishes_the_iteration():
	var s := _systems()
	world.debug_pause()
	_iterate()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	_iterate()
	assert_array([s[0].runs, s[1].runs]).is_equal([1, 0])
	assert_str(world.debug_step_state().cursor.group).is_equal("physics")

	world.debug_step(GECSStepper.Kind.FRAME)
	_iterate()
	# Physics had nothing left (group closed), render ran as part of the frame.
	assert_array([s[0].runs, s[1].runs]).is_equal([1, 1])
	_iterate()
	assert_int(_completed.size()).is_equal(2)
	assert_int(_completed[1].kind).is_equal(GECSStepper.Kind.FRAME)


func test_frame_step_log_includes_ops_from_every_group():
	var s := _systems()
	var e := Entity.new()
	e.name = "e"
	e.add_component(C_TestPosition.new())
	world.add_entity(e)
	world.debug_pause()
	_iterate()
	world.debug_step(GECSStepper.Kind.FRAME)
	_frame[0] += 1
	world.process(0.016, "physics")
	# A write made by game code between the group calls belongs to the frame.
	e.get_component(C_TestPosition).position = Vector3.ONE
	world.process(0.016, "render")
	_iterate()

	assert_int(_completed.size()).is_equal(1)
	var props: Array = _completed[0].ops.filter(func(op): return op[0] == GECSStepper.Op.PROP_SET)
	assert_int(props.size()).is_equal(1)
	assert_str(props[0][7]).is_equal("")
	assert_int(s[1].runs).is_equal(1)
