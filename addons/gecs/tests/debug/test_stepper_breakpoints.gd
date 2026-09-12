## Step debugger: breakpoints while live (system / component / entity) and
## inside multi-system steps.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var _completed: Array = []
var _hits: Array = []


class CounterSystem:
	extends System
	var runs := 0

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		runs += 1


class AdderSystem:
	extends System
	var runs := 0

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		runs += 1
		for e in entities:
			if not e.has_component(C_TestB):
				cmd.add_component(e, C_TestB.new())


class PerGroupAdder:
	extends System
	var runs := 0

	func _init() -> void:
		process_empty = true
		command_buffer_flush_mode = FlushMode.PER_GROUP

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		runs += 1
		for e in entities:
			if not e.has_component(C_TestB):
				cmd.add_component(e, C_TestB.new())


class RemoverSystem:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestB])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			cmd.remove_component(e, C_TestB)


class PositionWriter:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestPosition])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			e.get_component(C_TestPosition).position += Vector3.ONE


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func before_test():
	_completed = []
	_hits = []
	world.step_completed.connect(_on_step_completed)
	world.step_break_hit.connect(_on_break_hit)


func after_test():
	if world:
		if world.step_completed.is_connected(_on_step_completed):
			world.step_completed.disconnect(_on_step_completed)
		if world.step_break_hit.is_connected(_on_break_hit):
			world.step_break_hit.disconnect(_on_break_hit)
		world.debug_clear_breakpoints()
		world.purge(false)
		await get_tree().process_frame


func _on_step_completed(_kind: int, info: Dictionary) -> void:
	_completed.append(info)


func _on_break_hit(breakpoint_id: int, info: Dictionary) -> void:
	_hits.append([breakpoint_id, info])


func _add(system: System, system_name: String) -> System:
	system.name = system_name
	world.add_system(system)
	return system


func _entity(entity_name: String, components: Array) -> Entity:
	var e := Entity.new()
	e.name = entity_name
	for c in components:
		e.add_component(c)
	world.add_entity(e)
	return e


func test_system_breakpoint_pauses_before_the_system_without_running_it():
	var s1: CounterSystem = _add(CounterSystem.new(), "S1")
	var s2: CounterSystem = _add(CounterSystem.new(), "S2")
	var bp_id := world.debug_add_breakpoint({"kind": "system", "system": s2})
	assert_int(bp_id).is_not_equal(0)

	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_true()
	assert_array([s1.runs, s2.runs]).is_equal([1, 0])
	assert_int(_hits.size()).is_equal(1)
	assert_int(_hits[0][0]).is_equal(bp_id)
	var state := world.debug_step_state()
	assert_int(state.cursor.system_id).is_equal(s2.get_instance_id())
	assert_str(state.cursor.system_name).is_equal("S2")
	assert_int(state.breakpoints[0].hits).is_equal(1)
	assert_int(state.break_info.breakpoint_id).is_equal(bp_id)
	assert_str(state.break_info.system).is_equal("S2")
	assert_str(state.break_info.label).contains("before S2")
	# Reading again must retain the cause even after its log has been published.
	assert_dict(world.debug_step_state().break_info).is_equal(state.break_info)

	# The pause is settled at a live break: the very next call services the step.
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_array([s1.runs, s2.runs]).is_equal([1, 1])
	assert_dict(world.debug_step_state().break_info).is_empty()


func test_disabling_hit_breakpoint_preserves_reason_until_resume_and_stops_rebreaking():
	var system: CounterSystem = _add(CounterSystem.new(), "Movement")
	var bp_id := world.debug_add_breakpoint({"kind": "system", "system": system})
	world.process(0.016)
	assert_bool(world.debug_is_paused()).is_true()
	world.debug_set_breakpoint_enabled(bp_id, false)
	var state := world.debug_step_state()
	assert_int(state.break_info.breakpoint_id).is_equal(bp_id)
	assert_bool(state.breakpoints[0].enabled).is_false()
	world.debug_resume()
	for i in 3: world.process(0.016)
	assert_bool(world.debug_is_paused()).is_false()
	assert_int(system.runs).is_equal(3)
	assert_dict(world.debug_step_state().break_info).is_empty()
	world.debug_pause()
	assert_dict(world.debug_step_state().break_info).is_empty()


func test_component_added_breakpoint_pauses_after_the_triggering_system():
	var adder: AdderSystem = _add(AdderSystem.new(), "Adder")
	var s2: CounterSystem = _add(CounterSystem.new(), "S2")
	var e := _entity("e", [C_TestA.new()])
	var bp_id := world.debug_add_breakpoint({"kind": "component_added", "component": C_TestB})

	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_true()
	assert_array([adder.runs, s2.runs]).is_equal([1, 0])
	assert_bool(e.has_component(C_TestB)).is_true()
	var log: Dictionary = world.debug_stepper().last_step_log
	assert_str(log.kind_name).is_equal("break")
	assert_int(log.break_info.breakpoint_id).is_equal(bp_id)
	assert_str(log.break_info.op).is_equal("comp_add")
	assert_str(log.break_info.system).is_equal("Adder")
	var adds: Array = log.ops.filter(func(rec): return rec[0] == GECSStepper.Op.COMP_ADD)
	assert_int(adds.size()).is_equal(1)
	assert_str(adds[0][7]).is_equal("cmd")
	assert_str(world.debug_step_state().cursor.system_name).is_equal("S2")

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_array([adder.runs, s2.runs]).is_equal([1, 1])


func test_component_removed_breakpoint():
	_add(RemoverSystem.new(), "Remover")
	var s2: CounterSystem = _add(CounterSystem.new(), "S2")
	_entity("e", [C_TestA.new(), C_TestB.new()])
	world.debug_add_breakpoint({"kind": "component_removed", "component": C_TestB})

	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_true()
	assert_int(s2.runs).is_equal(0)
	assert_str(world.debug_stepper().last_step_log.break_info.op).is_equal("comp_remove")


func test_entity_breakpoint_fires_on_any_op_touching_it():
	_add(PositionWriter.new(), "Writer")
	var s2: CounterSystem = _add(CounterSystem.new(), "S2")
	var e := _entity("e", [C_TestPosition.new()])
	var bp_id := world.debug_add_breakpoint({"kind": "entity", "entity": e})

	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_true()
	assert_int(s2.runs).is_equal(0)
	var info: Dictionary = world.debug_stepper().last_step_log.break_info
	assert_int(info.breakpoint_id).is_equal(bp_id)
	assert_str(info.op).is_equal("prop_set")
	assert_int(info.entity_id).is_equal(e.get_instance_id())


func test_breakpoints_resolve_class_names_and_paths():
	var by_name := world.debug_add_breakpoint({"kind": "component_added", "component": "C_TestB"})
	var by_path := world.debug_add_breakpoint(
		{"kind": "component_added", "component": "res://addons/gecs/tests/components/c_test_b.gd"}
	)
	var missing := world.debug_add_breakpoint(
		{"kind": "component_added", "component": "C_DoesNotExistAnywhere"}
	)
	var bad_kind := world.debug_add_breakpoint({"kind": "nope"})

	assert_int(by_name).is_not_equal(0)
	assert_int(by_path).is_not_equal(0)
	assert_int(missing).is_equal(0)
	assert_int(bad_kind).is_equal(0)
	assert_int(world.debug_step_state().breakpoints.size()).is_equal(2)


func test_breakpoint_inside_group_flush_pauses_after_the_flush():
	var adder: PerGroupAdder = _add(PerGroupAdder.new(), "GroupAdder")
	var e := _entity("e", [C_TestA.new()])
	world.debug_add_breakpoint({"kind": "component_added", "component": C_TestB})

	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_true()
	assert_bool(e.has_component(C_TestB)).is_true()
	assert_str(world.debug_stepper().last_step_log.label).is_equal("break: (group flush)")
	assert_bool(world.debug_step_state().cursor.has_group).is_false()

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)
	assert_int(adder.runs).is_equal(2)


func test_breakpoint_outside_process_pauses_at_the_next_call():
	var s1: CounterSystem = _add(CounterSystem.new(), "S1")
	var e := _entity("e", [C_TestA.new()])
	world.debug_add_breakpoint({"kind": "component_added", "component": C_TestB})

	e.add_component(C_TestB.new())
	assert_bool(world.debug_is_paused()).is_false()
	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_true()
	assert_int(s1.runs).is_equal(0)
	var log: Dictionary = world.debug_stepper().last_step_log
	assert_str(log.label).is_equal("break: (external)")
	var adds: Array = log.ops.filter(func(rec): return rec[0] == GECSStepper.Op.COMP_ADD)
	assert_int(adds.size()).is_equal(1)
	assert_str(adds[0][7]).is_equal("(external)")


func test_disabled_breakpoint_does_not_fire():
	var s1: CounterSystem = _add(CounterSystem.new(), "S1")
	var s2: CounterSystem = _add(CounterSystem.new(), "S2")
	var bp_id := world.debug_add_breakpoint({"kind": "system", "system_id": s2.get_instance_id()})
	world.debug_set_breakpoint_enabled(bp_id, false)

	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_false()
	assert_array([s1.runs, s2.runs]).is_equal([1, 1])
	assert_bool(world.debug_step_state().breakpoints[0].enabled).is_false()


func test_clearing_breakpoints_leaves_the_world_flags_off():
	var s1: CounterSystem = _add(CounterSystem.new(), "S1")
	world.debug_add_breakpoint({"kind": "system", "system_name": "S1"})
	world.debug_add_breakpoint({"kind": "entity", "entity": _entity("e", [C_TestA.new()])})
	assert_bool(world._step_live_checks).is_true()
	assert_bool(world._step_hooks_active).is_true()

	world.debug_clear_breakpoints()
	world.debug_resume()

	assert_bool(world._step_paused).is_false()
	assert_bool(world._step_hooks_active).is_false()
	assert_bool(world._step_live_checks).is_false()
	assert_array(world.debug_step_state().breakpoints).is_empty()
	world.process(0.016)
	assert_int(s1.runs).is_equal(1)


func test_remove_breakpoint():
	var s1: CounterSystem = _add(CounterSystem.new(), "S1")
	var bp_id := world.debug_add_breakpoint({"kind": "system", "system": s1})
	world.debug_remove_breakpoint(bp_id)

	world.process(0.016)

	assert_bool(world.debug_is_paused()).is_false()
	assert_int(s1.runs).is_equal(1)


func test_breakpoint_hit_during_a_group_step_stops_early():
	var adder: AdderSystem = _add(AdderSystem.new(), "Adder")
	var s2: CounterSystem = _add(CounterSystem.new(), "S2")
	_entity("e", [C_TestA.new()])
	world.debug_pause()
	world.process(0.016)
	var bp_id := world.debug_add_breakpoint({"kind": "component_added", "component": C_TestB})

	world.debug_step(GECSStepper.Kind.GROUP)
	world.process(0.016)

	assert_array([adder.runs, s2.runs]).is_equal([1, 0])
	assert_int(_completed.size()).is_equal(1)
	assert_int(_completed[0].break_info.breakpoint_id).is_equal(bp_id)
	var state := world.debug_step_state()
	assert_bool(state.cursor.has_group).is_true()
	assert_str(state.cursor.system_name).is_equal("S2")
