## Step debugger: the per-step mutation journal (ops, causes, attribution,
## encoding, truncation) and the post-step silent-write sweep.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var _completed: Array = []


class PositionWriter:
	extends System
	var target := Vector3(1, 2, 3)

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestPosition])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			e.get_component(C_TestPosition).position = target


class CmdAdder:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			if not e.has_component(C_TestB):
				cmd.add_component(e, C_TestB.new())


class ChainObserver:
	extends Observer

	func query() -> QueryBuilder:
		return q.with_all([C_TestB]).on_added()

	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		cmd.add_component(entity, C_TestC.new())


class RemoverSystem:
	extends System
	var target: Entity

	func _init() -> void:
		process_empty = true
		safe_iteration = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		if is_instance_valid(target):
			ECS.world.remove_entity(target)
			target = null


class EventSystem:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			ECS.world.emit_event(&"boom", e, {"n": 1})


class SilentIncrementer:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			e.get_component(C_TestA).value += 1


class BogusEmitter:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestA])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			var a = e.get_component(C_TestA)
			a.value += 1
			a.property_changed.emit(a, "value", null, null)


class C_Plain:
	extends Component
	var counter := 0


class PlainIncrementer:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_Plain])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			e.get_component(C_Plain).counter += 1


class NameWriter:
	extends System
	var long_name := ""

	func _init() -> void:
		process_empty = true
		for i in 300:
			long_name += "x"

	func query() -> QueryBuilder:
		return q.with_all([C_ObserverTest])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			e.get_component(C_ObserverTest).name_prop = long_name


class Flood:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestPosition])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for e in entities:
			var p = e.get_component(C_TestPosition)
			for i in 2100:
				p.position = Vector3(i, 0, 0)


class Idle:
	extends System

	func _init() -> void:
		process_empty = true

	func query() -> QueryBuilder:
		return q.with_all([C_TestD])

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		pass


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


func _ops(op: int, info: Dictionary = {}) -> Array:
	var log: Dictionary = info if not info.is_empty() else _completed[_completed.size() - 1]
	return log.ops.filter(func(rec): return rec[0] == op)


func _pause_settle_step() -> void:
	world.debug_pause()
	world.process(0.016)
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)


func test_prop_set_journaled_with_system_attribution():
	_add(PositionWriter.new(), "Writer")
	var e := _entity("e", [C_TestPosition.new()])

	_pause_settle_step()

	var props := _ops(GECSStepper.Op.PROP_SET)
	assert_int(props.size()).is_equal(1)
	var rec: Array = props[0]
	assert_int(rec[1]).is_equal(e.get_instance_id())
	assert_str(rec[2]).is_equal("e")
	assert_str(rec[3]).is_equal("C_TestPosition")
	assert_str(rec[4]).is_equal("position")
	assert_that(rec[5]).is_equal(Vector3.ZERO)
	assert_that(rec[6]).is_equal(Vector3(1, 2, 3))
	assert_str(rec[7]).is_equal("")
	assert_str(rec[8]).is_equal("Writer")
	assert_array(_ops(GECSStepper.Op.SWEEP_SET)).is_empty()
	assert_array(_completed[0].touched).is_equal([e.get_instance_id()])


func test_cmd_cause_for_command_buffer_ops():
	_add(CmdAdder.new(), "Adder")
	_entity("e", [C_TestA.new()])

	_pause_settle_step()

	var adds := _ops(GECSStepper.Op.COMP_ADD)
	assert_int(adds.size()).is_equal(1)
	assert_str(adds[0][3]).is_equal("C_TestB")
	assert_str(adds[0][7]).is_equal("cmd")
	assert_str(adds[0][8]).is_equal("Adder")


func test_observer_cause_nested_with_cmd():
	var observer := ChainObserver.new()
	observer.name = "Chain"
	world.add_observer(observer)
	_add(CmdAdder.new(), "Adder")
	_entity("e", [C_TestA.new()])

	_pause_settle_step()

	var adds := _ops(GECSStepper.Op.COMP_ADD)
	assert_int(adds.size()).is_equal(2)
	assert_str(adds[0][3]).is_equal("C_TestB")
	assert_str(adds[0][7]).is_equal("cmd")
	assert_str(adds[1][3]).is_equal("C_TestC")
	assert_str(adds[1][7]).is_equal("cmd>observer:Chain>cmd")


func test_entity_remove_records_components_and_cascading_rel_remove():
	var remover: RemoverSystem = _add(RemoverSystem.new(), "Remover")
	var a := _entity("a", [C_TestA.new()])
	var b := _entity("b", [C_TestB.new()])
	a.add_relationship(Relationship.new(C_TestC.new(), b))
	remover.target = b

	_pause_settle_step()

	var removes := _ops(GECSStepper.Op.ENTITY_REMOVE)
	assert_int(removes.size()).is_equal(1)
	assert_str(removes[0][2]).is_equal("b")
	assert_array(removes[0][4]).is_equal(["C_TestB"])
	var rel_removes := _ops(GECSStepper.Op.REL_REMOVE)
	assert_int(rel_removes.size()).is_equal(1)
	assert_str(rel_removes[0][2]).is_equal("a")
	assert_str(rel_removes[0][3]).is_equal("C_TestC")
	assert_str(rel_removes[0][4]).is_equal("Entity b")
	var ops: Array = _completed[0].ops
	assert_bool(ops.find(removes[0]) < ops.find(rel_removes[0])).is_true()


func test_external_ops_are_logged_before_the_next_step():
	_add(Idle.new(), "Idle")
	var e := _entity("e", [C_TestA.new()])
	world.debug_pause()
	world.process(0.016)

	e.add_component(C_TestB.new())
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	var logs: Array = world.debug_stepper().step_logs
	assert_int(logs.size()).is_equal(2)
	assert_str(logs[0].label).is_equal("(external)")
	assert_str(logs[0].kind_name).is_equal("external")
	var adds := _ops(GECSStepper.Op.COMP_ADD, logs[0])
	assert_int(adds.size()).is_equal(1)
	assert_str(adds[0][7]).is_equal("(external)")
	assert_str(logs[1].label).is_equal("Idle")
	assert_int(_completed.size()).is_equal(1)


func test_direct_enabled_write_is_journaled():
	_add(Idle.new(), "Idle")
	var e := _entity("e", [C_TestA.new()])
	world.debug_pause()
	world.process(0.016)

	e.enabled = false
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	var logs: Array = world.debug_stepper().step_logs
	var enabled_ops := _ops(GECSStepper.Op.ENTITY_ENABLED, logs[0])
	assert_int(enabled_ops.size()).is_equal(1)
	assert_bool(enabled_ops[0][3]).is_false()


func test_custom_event_is_journaled():
	_add(EventSystem.new(), "Events")
	_entity("e", [C_TestA.new()])

	_pause_settle_step()

	var events := _ops(GECSStepper.Op.EVENT)
	assert_int(events.size()).is_equal(1)
	assert_str(events[0][3]).is_equal("boom")
	assert_that(events[0][4]).is_equal({"n": 1})


func test_long_string_values_are_truncated():
	_add(NameWriter.new(), "Names")
	_entity("e", [C_ObserverTest.new()])

	_pause_settle_step()

	var props := _ops(GECSStepper.Op.PROP_SET)
	assert_int(props.size()).is_equal(1)
	assert_int(String(props[0][6]).length()).is_equal(GECSStepper.MAX_STRING + 3)
	assert_bool(String(props[0][6]).ends_with("...")).is_true()


func test_step_log_truncates_at_the_op_cap():
	_add(Flood.new(), "Flood")
	_entity("e", [C_TestPosition.new()])

	_pause_settle_step()

	assert_int(_completed[0].op_count).is_equal(GECSStepper.MAX_OPS_PER_STEP)
	assert_bool(_completed[0].truncated).is_true()


func test_silent_write_is_reported_by_the_sweep():
	_add(SilentIncrementer.new(), "Silent")
	var e := _entity("e", [C_TestA.new()])

	_pause_settle_step()

	assert_array(_ops(GECSStepper.Op.PROP_SET)).is_empty()
	var sweeps := _ops(GECSStepper.Op.SWEEP_SET)
	assert_int(sweeps.size()).is_equal(1)
	assert_int(sweeps[0][1]).is_equal(e.get_instance_id())
	assert_str(sweeps[0][3]).is_equal("C_TestA")
	assert_str(sweeps[0][4]).is_equal("value")
	assert_int(sweeps[0][5]).is_equal(0)
	assert_int(sweeps[0][6]).is_equal(1)
	assert_str(sweeps[0][7]).is_equal("(sweep)")


func test_setter_write_is_not_double_reported():
	_add(PositionWriter.new(), "Writer")
	_entity("e", [C_TestPosition.new()])

	_pause_settle_step()

	assert_int(_ops(GECSStepper.Op.PROP_SET).size()).is_equal(1)
	assert_array(_ops(GECSStepper.Op.SWEEP_SET)).is_empty()


func test_setter_with_bogus_values_is_not_double_reported():
	_add(BogusEmitter.new(), "Bogus")
	_entity("e", [C_TestA.new()])

	_pause_settle_step()

	var props := _ops(GECSStepper.Op.PROP_SET)
	assert_int(props.size()).is_equal(1)
	assert_that(props[0][6]).is_null()
	assert_array(_ops(GECSStepper.Op.SWEEP_SET)).is_empty()


func test_non_export_var_is_caught_by_the_sweep():
	_add(PlainIncrementer.new(), "Plain")
	_entity("e", [C_Plain.new()])

	_pause_settle_step()

	var sweeps := _ops(GECSStepper.Op.SWEEP_SET)
	assert_int(sweeps.size()).is_equal(1)
	assert_str(sweeps[0][4]).is_equal("counter")
	assert_int(sweeps[0][6]).is_equal(1)


func test_sweep_off_reports_nothing():
	_add(SilentIncrementer.new(), "Silent")
	_entity("e", [C_TestA.new()])
	world.debug_set_sweep(false)

	_pause_settle_step()

	assert_array(_ops(GECSStepper.Op.SWEEP_SET)).is_empty()
	assert_int(_completed[0].op_count).is_equal(0)


func test_sweep_baseline_is_taken_at_the_first_paused_call():
	_add(SilentIncrementer.new(), "Silent")
	var e := _entity("e", [C_TestA.new()])
	world.debug_pause()
	e.get_component(C_TestA).value = 5  # before the settling call: part of the baseline
	world.process(0.016)

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	var sweeps := _ops(GECSStepper.Op.SWEEP_SET)
	assert_int(sweeps.size()).is_equal(1)
	assert_int(sweeps[0][5]).is_equal(5)
	assert_int(sweeps[0][6]).is_equal(6)


func test_removed_component_is_dropped_silently():
	_add(Idle.new(), "Idle")
	var e := _entity("e", [C_TestA.new()])
	world.debug_pause()
	world.process(0.016)

	e.remove_component(C_TestA)
	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	assert_array(_ops(GECSStepper.Op.SWEEP_SET)).is_empty()
	var logs: Array = world.debug_stepper().step_logs
	assert_int(_ops(GECSStepper.Op.COMP_REMOVE, logs[0]).size()).is_equal(1)
