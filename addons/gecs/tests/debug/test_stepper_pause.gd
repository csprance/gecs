## Step debugger: pause / resume and SYSTEM / GROUP granularity, driven the way
## a game drives it (repeated world.process calls while paused).
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var _completed: Array = []


class CounterSystem:
	extends System
	var runs := 0
	var calls: Array = []
	var deltas: Array = []
	var comp: Script

	func _init(component: Script = C_TestA, group_name: String = "") -> void:
		comp = component
		group = group_name
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([comp])

	func process(entities: Array[Entity], _components: Array, delta: float) -> void:
		runs += 1
		deltas.append(delta)
		var names := []
		for e in entities:
			names.append(String(e.name))
		calls.append(names)


class SpawnerPerGroup:
	extends System

	func _init() -> void:
		process_empty = true
		command_buffer_flush_mode = FlushMode.PER_GROUP

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for _e in entities:
			var spawned := Entity.new()
			spawned.name = "spawned"
			spawned.add_component(C_TestB.new())
			cmd.add_entity(spawned)


class SpawnerPerSystem:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for _e in entities:
			var spawned := Entity.new()
			spawned.name = "spawned"
			spawned.add_component(C_TestB.new())
			cmd.add_entity(spawned)


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func before_test():
	_completed = []
	world.step_completed.connect(_on_step_completed)


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


func _system(name: String, component: Script = C_TestA, group_name: String = "") -> CounterSystem:
	var system := CounterSystem.new(component, group_name)
	system.name = name
	world.add_system(system)
	return system


func _entity(entity_name: String, components: Array) -> Entity:
	var e := Entity.new()
	e.name = entity_name
	for c in components:
		e.add_component(c)
	world.add_entity(e)
	return e


func _settle(group: String = "") -> void:
	# First paused call: settles the pause (sweep baseline, frame id).
	world.process(0.016, group)


func test_paused_world_runs_nothing():
	var a := _system("A", C_TestA)
	var b := _system("B", C_TestB)
	b.set_tick_rate(0.5)
	_entity("e1", [C_TestA.new()])
	world.process(0.1)
	assert_int(a.runs).is_equal(1)
	assert_int(b.runs).is_equal(0)
	var tick_before := Archetype.global_change_tick

	world.debug_pause()
	for i in 5:
		world.process(0.5)

	assert_bool(world.debug_is_paused()).is_true()
	assert_int(a.runs).is_equal(1)
	assert_int(b.runs).is_equal(0)
	assert_float(b.tick_source.time_elapsed).is_equal_approx(0.1, 0.0001)
	assert_int(b.tick_source.tick_count).is_equal(0)
	assert_int(Archetype.global_change_tick).is_equal(tick_before)


func test_resume_runs_live_again():
	var a := _system("A")
	_entity("e1", [C_TestA.new()])
	world.debug_pause()
	world.process(0.016)
	assert_int(a.runs).is_equal(0)

	world.debug_resume()
	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_false()
	assert_int(a.runs).is_equal(1)
	assert_bool(world._step_hooks_active).is_false()
	assert_bool(world._step_live_checks).is_false()


func test_step_system_runs_exactly_one_in_order():
	var s1 := _system("S1")
	var s2 := _system("S2")
	var s3 := _system("S3")
	_entity("e1", [C_TestA.new()])
	world.debug_pause()
	_settle()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_array([s1.runs, s2.runs, s3.runs]).is_equal([1, 0, 0])
	assert_int(_completed.size()).is_equal(1)
	assert_int(_completed[0].kind).is_equal(GECSStepper.Kind.SYSTEM)
	assert_int(_completed[0].system_id).is_equal(s1.get_instance_id())
	assert_str(_completed[0].label).is_equal("S1")

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_array([s1.runs, s2.runs, s3.runs]).is_equal([1, 1, 0])

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_array([s1.runs, s2.runs, s3.runs]).is_equal([1, 1, 1])

	# End of group with nothing to flush: the group closes and the request waits
	# for the next call, which re-adopts the group from the top.
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_array([s1.runs, s2.runs, s3.runs]).is_equal([1, 1, 1])
	assert_int(world.debug_step_state().pending_requests).is_equal(1)
	world.process(0.016)
	assert_array([s1.runs, s2.runs, s3.runs]).is_equal([2, 1, 1])
	assert_int(_completed.size()).is_equal(4)


func test_step_count_runs_multiple_steps_in_one_call():
	var s1 := _system("S1")
	var s2 := _system("S2")
	var s3 := _system("S3")
	world.debug_pause()
	_settle()

	world.debug_step(GECSStepper.Kind.SYSTEM, 2)
	world.process(0.016)

	assert_array([s1.runs, s2.runs, s3.runs]).is_equal([1, 1, 0])
	assert_int(_completed.size()).is_equal(2)


func test_step_uses_the_game_call_delta():
	var s1 := _system("S1")
	world.debug_pause()
	_settle()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.123)

	assert_float(s1.deltas[0]).is_equal_approx(0.123, 0.0001)


func test_step_system_skips_gated_systems_and_logs_them():
	var s1 := _system("S1")
	s1.active = false
	var s2 := _system("S2")
	s2.paused = true
	var s3 := _system("S3")
	s3.set_tick_rate(10.0)
	var s4 := _system("S4")
	world.debug_pause()
	_settle()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	assert_array([s1.runs, s2.runs, s3.runs, s4.runs]).is_equal([0, 0, 0, 1])
	assert_int(_completed.size()).is_equal(1)
	assert_array(_completed[0].skipped).contains(["S1", "S2", "S3"])
	assert_int(_completed[0].system_id).is_equal(s4.get_instance_id())


func test_step_system_stops_at_group_flush_when_pending():
	var spawner := SpawnerPerGroup.new()
	spawner.name = "Spawner"
	world.add_system(spawner)
	var dependent := _system("Dependent", C_TestB)
	_entity("e1", [C_TestA.new()])
	world.debug_pause()
	_settle()
	var count_before := world.entities.size()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_int(world.entities.size()).is_equal(count_before)
	assert_str(world.debug_step_state().cursor.system_name).is_equal("Dependent")

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_int(dependent.runs).is_equal(1)
	assert_array(dependent.calls[0]).is_empty()
	assert_str(world.debug_step_state().cursor.next_label).is_equal("(group flush)")

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_int(world.entities.size()).is_equal(count_before + 1)
	var flush_log: Dictionary = _completed[2]
	assert_str(flush_log.label).is_equal("(group flush)")
	var entity_adds: Array = flush_log.ops.filter(func(op): return op[0] == GECSStepper.Op.ENTITY_ADD)
	assert_int(entity_adds.size()).is_equal(1)
	assert_str(entity_adds[0][7]).is_equal("cmd")
	assert_bool(world.debug_step_state().cursor.has_group).is_false()


func test_step_system_closes_group_when_nothing_pending():
	var spawner := SpawnerPerSystem.new()
	spawner.name = "Spawner"
	world.add_system(spawner)
	_entity("e1", [C_TestA.new()])
	world.debug_pause()
	_settle()
	var count_before := world.entities.size()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	# PER_SYSTEM flush is part of the system's own step.
	assert_int(world.entities.size()).is_equal(count_before + 1)
	assert_str(world.debug_step_state().cursor.next_label).is_equal("(end of group)")


func test_group_step_runs_rest_of_group_and_flush():
	var spawner := SpawnerPerGroup.new()
	spawner.name = "Spawner"
	world.add_system(spawner)
	var s2 := _system("S2")
	var s3 := _system("S3")
	_entity("e1", [C_TestA.new()])
	world.debug_pause()
	_settle()
	var count_before := world.entities.size()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	world.debug_step(GECSStepper.Kind.GROUP)
	world.process(0.016)

	assert_array([s2.runs, s3.runs]).is_equal([1, 1])
	assert_int(world.entities.size()).is_equal(count_before + 1)
	assert_int(_completed.size()).is_equal(2)
	assert_int(_completed[1].kind).is_equal(GECSStepper.Kind.GROUP)
	assert_array(_completed[1].systems).is_equal(["S2", "S3"])
	assert_bool(world.debug_step_state().cursor.has_group).is_false()


func test_self_removing_system_does_not_skip_the_next_system():
	var self_removing := SelfRemovingSystem.new()
	self_removing.name = "SelfRemoving"
	world.add_system(self_removing)
	var s2 := _system("S2")
	world.debug_pause()
	_settle()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_int(self_removing.run_count).is_equal(1)
	assert_int(s2.runs).is_equal(0)

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_int(s2.runs).is_equal(1)


func test_timers_advance_once_per_group_adoption():
	var plain := _system("Plain")
	var timed := _system("Timed", C_TestB)
	timed.set_tick_rate(0.5)
	world.debug_pause()
	_settle()

	# Adopt + run Plain (timer 0.25).
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.25)
	assert_int(plain.runs).is_equal(1)
	# Timed is gated: skipped, group closes, request waits.
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.25)
	assert_int(timed.runs).is_equal(0)
	assert_float(timed.tick_source.time_elapsed).is_equal_approx(0.25, 0.0001)
	# Re-adopt (timer 0.5 -> ticks), Plain runs; then Timed runs.
	world.process(0.25)
	assert_int(plain.runs).is_equal(2)
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.25)
	assert_int(timed.runs).is_equal(1)
	assert_int(timed.tick_source.tick_count).is_equal(1)


func test_paused_call_for_group_without_systems_does_not_consume_request():
	var phys := _system("Phys", C_TestA, "physics")
	world.debug_pause()
	_settle("physics")

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016, "render")
	assert_int(phys.runs).is_equal(0)
	assert_int(world.debug_step_state().pending_requests).is_equal(1)

	world.process(0.016, "physics")
	assert_int(phys.runs).is_equal(1)


func test_paused_call_for_another_group_is_skipped_while_cursor_is_busy():
	var phys1 := _system("Phys1", C_TestA, "physics")
	var phys2 := _system("Phys2", C_TestA, "physics")
	var rend := _system("Rend", C_TestA, "render")
	world.debug_pause()
	_settle("physics")

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016, "physics")
	assert_int(phys1.runs).is_equal(1)
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016, "render")
	assert_int(rend.runs).is_equal(0)
	world.process(0.016, "physics")
	assert_int(phys2.runs).is_equal(1)


func test_resume_mid_system_finishes_the_system():
	var spawner := SpawnerPerSystem.new()
	spawner.name = "Spawner"
	world.add_system(spawner)
	_entity("e1", [C_TestA.new()])
	_entity("e2", [C_TestA.new(), C_TestC.new()])
	world.debug_pause()
	_settle()
	var count_before := world.entities.size()

	world.debug_step(GECSStepper.Kind.ARCHETYPE)
	world.process(0.016)
	assert_bool(world.debug_step_state().cursor.in_system).is_true()
	assert_int(world.entities.size()).is_equal(count_before)

	world.debug_resume()

	# Remaining archetype ran and the PER_SYSTEM flush happened on resume.
	assert_int(world.entities.size()).is_equal(count_before + 2)
	assert_bool(world.debug_is_paused()).is_false()


func test_step_while_live_pauses_first():
	var s1 := _system("S1")
	var s2 := _system("S2")
	world.process(0.016)
	assert_array([s1.runs, s2.runs]).is_equal([1, 1])

	world.debug_step(GECSStepper.Kind.SYSTEM)
	assert_bool(world.debug_is_paused()).is_true()
	# The first paused call settles the pause AND services a SYSTEM step (only
	# FRAME steps wait for an iteration boundary).
	world.process(0.016)

	assert_array([s1.runs, s2.runs]).is_equal([2, 1])
