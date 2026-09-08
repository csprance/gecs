## Step debugger: ARCHETYPE and ENTITY granularity (resumable system execution)
## and parity with the live _handle path.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var _completed: Array = []


class RecordingSystem:
	extends System
	var runs := 0
	var calls: Array = []

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		runs += 1
		var names := []
		for e in entities:
			names.append(String(e.name))
		calls.append(names)


class IncrementSystem:
	extends System

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).iterate([C_TestA])

	func process(entities: Array[Entity], components: Array, _delta: float) -> void:
		var column: Array = components[0]
		for i in entities.size():
			column[i].value += 1
			entities[i].mark_changed(column[i])


class ChangedSystem:
	extends System
	var runs := 0
	var seen: Array = []

	func query() -> QueryBuilder:
		return q.with_all([C_TestA]).changed([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		runs += 1
		seen.append(entities.size())


class SubsystemSystem:
	extends System
	var first_runs := 0
	var second_saw := -1
	var timed_runs := 0
	var _timer: SystemTimer

	func setup() -> void:
		process_empty = true
		safe_iteration = true
		_timer = SystemTimer.new()
		_timer.interval = 0.5

	func sub_systems() -> Array[Array]:
		return [
			[q.with_all([C_TestA]), _first],
			[q.with_all([C_TestB]), _second],
			[q.with_all([C_TestA]), _timed, _timer],
		]

	func _first(entities: Array[Entity], _c: Array, _d: float) -> void:
		first_runs += 1
		for e in entities:
			if not e.has_component(C_TestB):
				e.add_component(C_TestB.new())

	func _second(entities: Array[Entity], _c: Array, _d: float) -> void:
		second_saw = entities.size()

	func _timed(_entities: Array[Entity], _c: Array, _d: float) -> void:
		timed_runs += 1


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


func _entity(entity_name: String, components: Array) -> Entity:
	var e := Entity.new()
	e.name = entity_name
	for c in components:
		e.add_component(c)
	world.add_entity(e)
	return e


func _settle() -> void:
	world.process(0.016)


func _step(kind: int, count: int = 1) -> void:
	world.debug_step(kind, count)
	world.process(0.016)


func test_archetype_step_runs_one_process_call_per_step():
	var system := RecordingSystem.new()
	system.name = "Rec"
	world.add_system(system)
	_entity("only_a", [C_TestA.new()])
	_entity("a_b", [C_TestA.new(), C_TestB.new()])
	_entity("a_c", [C_TestA.new(), C_TestC.new()])
	world.debug_pause()
	_settle()

	_step(GECSStepper.Kind.ARCHETYPE)
	assert_int(system.runs).is_equal(1)
	assert_int(system.calls[0].size()).is_equal(1)
	assert_bool(world.debug_step_state().cursor.in_system).is_true()
	_step(GECSStepper.Kind.ARCHETYPE)
	assert_int(system.runs).is_equal(2)
	_step(GECSStepper.Kind.ARCHETYPE)
	assert_int(system.runs).is_equal(3)
	assert_bool(world.debug_step_state().cursor.in_system).is_false()

	var all_names := []
	for call in system.calls:
		all_names.append_array(call)
	assert_array(all_names).contains_exactly_in_any_order(["only_a", "a_b", "a_c"])
	assert_int(_completed.size()).is_equal(3)
	assert_int(_completed[0].kind).is_equal(GECSStepper.Kind.ARCHETYPE)
	assert_str(_completed[0].label).contains("Rec / [")


func test_entity_step_isolates_step_set_members_in_order():
	var system := RecordingSystem.new()
	system.name = "Rec"
	world.add_system(system)
	_entity("a", [C_TestA.new()])
	var b := _entity("b", [C_TestA.new()])
	_entity("c", [C_TestA.new()])
	_entity("d", [C_TestA.new()])
	world.debug_pause()
	_settle()
	world.debug_set_step_entities([b])

	_step(GECSStepper.Kind.ENTITY)
	_step(GECSStepper.Kind.ENTITY)
	_step(GECSStepper.Kind.ENTITY)

	assert_array(system.calls).is_equal([["a"], ["b"], ["c", "d"]])
	assert_str(_completed[1].label).contains("entity b")
	assert_bool(world.debug_step_state().cursor.in_system).is_false()


func test_step_set_accepts_instance_ids_and_prunes_removed_entities():
	var a := _entity("a", [C_TestA.new()])
	var b := _entity("b", [C_TestA.new()])
	world.debug_pause()
	world.debug_set_step_entities([a.get_instance_id(), b])
	assert_array(world.debug_step_state().step_entities).contains_exactly_in_any_order(
		[a.get_instance_id(), b.get_instance_id()]
	)

	world.remove_entity(b)

	assert_array(world.debug_step_state().step_entities).is_equal([a.get_instance_id()])


func test_empty_step_set_entity_step_behaves_like_archetype():
	var system := RecordingSystem.new()
	system.name = "Rec"
	world.add_system(system)
	for n in ["a", "b", "c", "d"]:
		_entity(n, [C_TestA.new()])
	world.debug_pause()
	_settle()

	_step(GECSStepper.Kind.ENTITY)

	assert_int(system.runs).is_equal(1)
	assert_int(system.calls[0].size()).is_equal(4)


func test_zero_unit_system_with_process_empty_calls_process_once():
	var system := RecordingSystem.new()
	system.name = "Rec"
	world.add_system(system)
	_entity("no_a", [C_TestB.new()])
	world.debug_pause()
	_settle()

	_step(GECSStepper.Kind.ARCHETYPE)

	assert_int(system.runs).is_equal(1)
	assert_array(system.calls[0]).is_empty()
	assert_str(_completed[0].label).contains("no matching entities")
	assert_bool(world.debug_step_state().cursor.in_system).is_false()


func test_change_detection_baselines_match_live():
	var system := ChangedSystem.new()
	system.name = "Changed"
	world.add_system(system)
	var e := _entity("e", [C_TestA.new()])
	var comp: C_TestA = e.get_component(C_TestA)
	# Live reference: add counts as a write, then nothing, then a write.
	world.process(0.016)
	world.process(0.016)
	e.mark_changed(comp)
	world.process(0.016)
	assert_int(system.runs).is_equal(2)
	assert_array(system.seen).is_equal([1, 1])
	system.runs = 0
	system.seen = []
	e.mark_changed(comp)

	world.debug_pause()
	_settle()
	_step(GECSStepper.Kind.ARCHETYPE)  # sees the pending write
	assert_int(system.runs).is_equal(1)
	# System ended (one archetype); a further step closes the group, then the
	# next call re-adopts and finds nothing changed: begin/end only.
	_step(GECSStepper.Kind.ARCHETYPE)
	world.process(0.016)
	assert_int(system.runs).is_equal(1)
	e.mark_changed(comp)
	_step(GECSStepper.Kind.ARCHETYPE)
	world.process(0.016)

	assert_int(system.runs).is_equal(2)
	assert_array(system.seen).is_equal([1, 1])


func test_later_subsystem_sees_earlier_subsystem_mutation_and_timer_advances_once():
	var system := SubsystemSystem.new()
	system.name = "Subs"
	world.add_system(system)
	_entity("e", [C_TestA.new()])
	world.debug_pause()
	_settle()

	# Phase 0 (adds C_TestB directly), phase 1 (sees it), phase 2 timer-gated.
	world.debug_step(GECSStepper.Kind.ARCHETYPE)
	world.process(0.25)
	assert_int(system.first_runs).is_equal(1)
	world.debug_step(GECSStepper.Kind.ARCHETYPE)
	world.process(0.25)
	assert_int(system.second_saw).is_equal(1)
	assert_bool(world.debug_step_state().cursor.in_system).is_false()
	assert_int(system.timed_runs).is_equal(0)
	assert_float(system._timer.time_elapsed).is_equal_approx(0.25, 0.0001)

	# Second pass: the subsystem timer reaches 0.5 and the timed phase runs.
	world.debug_step(GECSStepper.Kind.ARCHETYPE)
	world.process(0.25)
	world.process(0.25)
	assert_int(system.first_runs).is_equal(2)
	world.debug_step(GECSStepper.Kind.ARCHETYPE, 2)
	world.process(0.25)
	assert_int(system.timed_runs).is_equal(1)


func test_parity_archetype_and_entity_steps_vs_live():
	var system := IncrementSystem.new()
	system.name = "Inc"
	world.add_system(system)
	var live := []
	live.append(_entity("l1", [C_TestA.new(1)]))
	live.append(_entity("l2", [C_TestA.new(10), C_TestB.new()]))
	live.append(_entity("l3", [C_TestA.new(100), C_TestC.new()]))
	for i in 3:
		world.process(0.016)
	var live_values := []
	for e in live:
		live_values.append(e.get_component(C_TestA).value)
	for e in live:
		world.remove_entity(e)
	assert_array(live_values).is_equal([4, 13, 103])

	var stepped := []
	stepped.append(_entity("s1", [C_TestA.new(1)]))
	stepped.append(_entity("s2", [C_TestA.new(10), C_TestB.new()]))
	stepped.append(_entity("s3", [C_TestA.new(100), C_TestC.new()]))
	world.debug_pause()
	_settle()
	world.debug_set_step_entities([stepped[1]])
	# 3 frames: each frame = 3 archetypes worth of units, then the group closes
	# and the request waits for the next call.
	var kinds := [GECSStepper.Kind.ARCHETYPE, GECSStepper.Kind.ENTITY, GECSStepper.Kind.ARCHETYPE]
	for frame in 3:
		world.debug_step(kinds[frame], 3)
		world.process(0.016)
		world.process(0.016)

	var stepped_values := []
	for e in stepped:
		stepped_values.append(e.get_component(C_TestA).value)
	assert_array(stepped_values).is_equal(live_values)


func test_entities_freed_between_units_are_skipped():
	var system := RecordingSystem.new()
	system.name = "Rec"
	world.add_system(system)
	_entity("a", [C_TestA.new()])
	var b := _entity("b", [C_TestA.new()])
	var c := _entity("c", [C_TestA.new()])
	world.debug_pause()
	_settle()
	world.debug_set_step_entities([b, c])

	_step(GECSStepper.Kind.ENTITY)  # [a]
	world.remove_entity(c)
	_step(GECSStepper.Kind.ENTITY)  # [b]
	_step(GECSStepper.Kind.ENTITY)  # [c] gone: skipped, system ends

	assert_array(system.calls).is_equal([["a"], ["b"]])
	assert_int(_completed.size()).is_equal(3)
	assert_bool(_completed[2].skipped.size() >= 1).is_true()
	assert_bool(world.debug_step_state().cursor.in_system).is_false()
