## Step debugger: the graph payload (GECSGraphState), the editor command
## channel (ECS._on_debugger_message -> World -> GECSStepper) and the messages
## the stepper sends back through the test sink.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var _captured: Array = []
var _saved_attached: bool
var _saved_cache: int
var _saved_sink: Callable
var _saved_debug: bool
var _saved_telemetry: bool
var _saved_lifecycle: bool
var _saved_props: bool


class CounterSystem:
	extends System
	var runs := 0

	func _init() -> void:
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
	_saved_attached = GECSEditorDebuggerMessages.attached
	_saved_cache = GECSEditorDebuggerMessages._attached_cache
	_saved_sink = GECSEditorDebuggerMessages._test_sink
	_saved_debug = ECS.debug
	_saved_telemetry = GECSEditorDebuggerMessages.telemetry_active
	_saved_lifecycle = GECSEditorDebuggerMessages.lifecycle_active
	_saved_props = GECSEditorDebuggerMessages.property_changes_active
	ECS.debug = true
	_captured = []
	GECSEditorDebuggerMessages._test_sink = func(m, d): _captured.append([m, d])
	GECSEditorDebuggerMessages.refresh_attached()


func after_test():
	GECSEditorDebuggerMessages._test_sink = _saved_sink
	GECSEditorDebuggerMessages._attached_cache = _saved_cache
	GECSEditorDebuggerMessages.attached = _saved_attached
	GECSEditorDebuggerMessages.telemetry_active = _saved_telemetry
	GECSEditorDebuggerMessages.lifecycle_active = _saved_lifecycle
	GECSEditorDebuggerMessages.property_changes_active = _saved_props
	ECS.debug = _saved_debug
	if world:
		world.debug_clear_breakpoints()
		world.purge(false)
		await get_tree().process_frame


func _entity(entity_name: String, components: Array) -> Entity:
	var e := Entity.new()
	e.name = entity_name
	for c in components:
		e.add_component(c)
	world.add_entity(e)
	return e


func _messages(name: String) -> Array:
	return _captured.filter(func(pair): return pair[0] == name)


func _node(graph: Dictionary, key: String) -> Dictionary:
	for node in graph.nodes:
		if node.key == key:
			return node
	return {}


func test_build_watched_with_components_and_outbound_edges():
	var a := _entity("a", [C_TestA.new(3)])
	var b := _entity("b", [C_TestC.new()])
	a.add_relationship(Relationship.new(C_TestB.new(), b))

	var graph := GECSGraphState.build(world, [a])

	assert_array(graph.watched).is_equal([a.get_instance_id()])
	var a_node := _node(graph, "e:%d" % a.get_instance_id())
	assert_bool(a_node.watched).is_true()
	assert_bool(a_node.stub).is_false()
	assert_str(a_node.name).is_equal("a")
	assert_int(a_node.components.size()).is_equal(1)
	assert_str(a_node.components[0].type).is_equal("C_TestA")
	assert_that(a_node.components[0].data.value).is_equal(3)
	var b_node := _node(graph, "e:%d" % b.get_instance_id())
	assert_bool(b_node.stub).is_true()
	assert_array(b_node.components).is_empty()
	assert_int(graph.edges.size()).is_equal(1)
	assert_str(graph.edges[0]["from"]).is_equal("e:%d" % a.get_instance_id())
	assert_str(graph.edges[0]["to"]).is_equal("e:%d" % b.get_instance_id())
	assert_str(graph.edges[0].relation_type).contains("c_test_b")
	assert_str(graph.edges[0].target_type).is_equal("Entity")


func test_inbound_source_is_a_stub_at_depth_0_and_full_at_depth_1():
	var a := _entity("a", [C_TestA.new()])
	var b := _entity("b", [C_TestC.new()])
	a.add_relationship(Relationship.new(C_TestB.new(), b))

	var shallow := GECSGraphState.build(world, [b], 0)
	assert_int(shallow.edges.size()).is_equal(1)
	assert_bool(_node(shallow, "e:%d" % a.get_instance_id()).stub).is_true()

	var deep := GECSGraphState.build(world, [b], 1)
	var a_node := _node(deep, "e:%d" % a.get_instance_id())
	assert_bool(a_node.stub).is_false()
	assert_bool(a_node.watched).is_false()
	assert_int(a_node.components.size()).is_equal(1)
	assert_int(deep.edges.size()).is_equal(1)


func test_script_component_and_wildcard_targets_become_nodes():
	var a := _entity("a", [C_TestA.new()])
	a.add_relationship(Relationship.new(C_TestB.new(), C_TestC))
	a.add_relationship(Relationship.new(C_TestB.new(), C_TestD.new()))
	a.add_relationship(Relationship.new(C_TestE.new(), null))

	var graph := GECSGraphState.build(world, [a])

	var kinds := []
	for node in graph.nodes:
		kinds.append(node.kind)
	assert_array(kinds).contains(["entity", "script", "component", "wildcard"])
	assert_int(graph.edges.size()).is_equal(3)
	var script_node := _node(graph, "s:res://addons/gecs/tests/components/c_test_c.gd")
	assert_str(script_node.label).is_equal("C_TestC")


func test_freed_target_edge_is_skipped_and_counted():
	var a := _entity("a", [C_TestA.new()])
	var b := _entity("b", [])
	a.add_relationship(Relationship.new(C_TestB.new(), b))
	b.free()

	var graph := GECSGraphState.build(world, [a])

	assert_array(graph.edges).is_empty()
	assert_int(_node(graph, "e:%d" % a.get_instance_id()).dangling).is_equal(1)


func test_graph_and_log_are_pulled_after_a_step():
	var system := CounterSystem.new()
	system.name = "S1"
	world.add_system(system)
	var a := _entity("a", [C_TestA.new()])
	world.debug_graph_watch([a])
	var pushed_on_watch := _messages(GECSEditorDebuggerMessages.Msg.GRAPH_STATE).size()
	assert_int(pushed_on_watch).is_equal(0)
	world.debug_pause()
	world.process(0.016)

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	assert_array(_messages(GECSEditorDebuggerMessages.Msg.GRAPH_STATE)).is_empty()
	var payload := world.debug_graph_state()
	assert_array(payload.watched).is_equal([a.get_instance_id()])
	assert_array(_messages(GECSEditorDebuggerMessages.Msg.STEP_LOG)).is_empty()
	var log: Dictionary = world.debug_explorer().debugger_state().logs[0]
	assert_str(log.label).is_equal("S1")


func test_open_graphs_are_pulled_and_pruned_on_removal():
	var system := CounterSystem.new()
	system.name = "S1"
	world.add_system(system)
	var a := _entity("a", [C_TestA.new()])
	var b := _entity("b", [C_TestA.new()])
	world.debug_graph_watch([a], 0, 1)
	world.debug_graph_watch([a, b], 1, 2)
	assert_int(world.debug_step_state().graphs.size()).is_equal(2)
	world.debug_pause()
	world.process(0.016)
	_captured = []

	world.debug_step(GECSStepper.Kind.SYSTEM)
	world.process(0.016)

	assert_array(_messages(GECSEditorDebuggerMessages.Msg.GRAPH_STATE)).is_empty()
	assert_array(world.debug_graph_state(2).watched).is_equal([a.get_instance_id(), b.get_instance_id()])

	world.remove_entity(b)
	assert_array(world.debug_step_state().graphs[2].watch).is_equal([a.get_instance_id()])
	world.debug_graph_close(2)
	assert_bool(world.debug_step_state().graphs.has(2)).is_false()
	assert_bool(world.debug_step_state().graphs.has(1)).is_true()
	# An empty watch set closes the graph too.
	world.debug_graph_watch([], 0, 1)
	assert_bool(world.debug_step_state().graphs.is_empty()).is_true()
	assert_array(world.debug_graph_state(1).nodes).is_empty()


func test_commands_drive_the_stepper():
	var system := CounterSystem.new()
	system.name = "S1"
	world.add_system(system)
	var e := _entity("e", [C_TestA.new()])
	var iid := e.get_instance_id()

	assert_bool(ECS._on_debugger_message("step_pause", [])).is_true()
	assert_bool(world.debug_is_paused()).is_true()

	assert_bool(ECS._on_debugger_message("step", [GECSStepper.Kind.SYSTEM, 1])).is_true()
	world.process(0.016)
	world.process(0.016)
	assert_int(system.runs).is_equal(1)

	assert_bool(ECS._on_debugger_message("step_set_entities", [[iid]])).is_true()
	assert_array(world.debug_step_state().step_entities).is_equal([iid])

	assert_bool(ECS._on_debugger_message("step_set_sweep", [false])).is_true()
	assert_bool(world.debug_step_state().sweep_enabled).is_false()

	assert_bool(
		ECS._on_debugger_message("breakpoint_add", [{"kind": "system", "system_id": system.get_instance_id()}])
	).is_true()
	var bps: Array = world.debug_step_state().breakpoints
	assert_int(bps.size()).is_equal(1)
	var bp_id: int = bps[0].id
	assert_bool(ECS._on_debugger_message("breakpoint_set_enabled", [bp_id, false])).is_true()
	assert_bool(world.debug_step_state().breakpoints[0].enabled).is_false()
	assert_bool(ECS._on_debugger_message("breakpoint_remove", [bp_id])).is_true()
	assert_array(world.debug_step_state().breakpoints).is_empty()
	ECS._on_debugger_message("breakpoint_add", [{"kind": "entity", "entity": iid}])
	assert_bool(ECS._on_debugger_message("breakpoint_clear", [])).is_true()
	assert_array(world.debug_step_state().breakpoints).is_empty()

	var graphs_before := _messages(GECSEditorDebuggerMessages.Msg.GRAPH_STATE).size()
	assert_bool(ECS._on_debugger_message("graph_watch", [5, [iid], 1])).is_true()
	assert_array(world.debug_step_state().graphs[5].watch).is_equal([iid])
	assert_int(world.debug_step_state().graphs[5].depth).is_equal(1)
	assert_bool(ECS._on_debugger_message("graph_pull", [5])).is_true()
	var graph_msgs := _messages(GECSEditorDebuggerMessages.Msg.GRAPH_STATE)
	assert_int(graph_msgs.size()).is_equal(graphs_before)
	assert_array(world.debug_graph_state(5).watched).is_equal([iid])
	assert_bool(ECS._on_debugger_message("graph_close", [5])).is_true()
	assert_bool(world.debug_step_state().graphs.has(5)).is_false()

	var states_before := _messages(GECSEditorDebuggerMessages.Msg.STEP_STATE).size()
	assert_bool(ECS._on_debugger_message("step_pull_state", [])).is_true()
	assert_int(_messages(GECSEditorDebuggerMessages.Msg.STEP_STATE).size()).is_equal(states_before)

	assert_bool(ECS._on_debugger_message("step_resume", [])).is_true()
	assert_bool(world.debug_is_paused()).is_false()

	assert_bool(ECS._on_debugger_message("step_bogus", [])).is_false()


func test_step_state_payload_shape():
	world.debug_pause()

	var state := world.debug_step_state()

	for key in [
		"paused",
		"cursor",
		"step_entities",
		"sweep_enabled",
		"breakpoints",
		"graphs",
		"step_counter",
		"pending_requests",
		"frame_step_active",
		"break_info",
	]:
		assert_bool(state.has(key)).override_failure_message("missing key " + key).is_true()
	for key in ["has_group", "group", "slot", "system_id", "system_name", "in_system", "unit_index", "unit_count", "unit_label", "next_label"]:
		assert_bool(state.cursor.has(key)).override_failure_message("missing cursor key " + key).is_true()
	var sent := _messages(GECSEditorDebuggerMessages.Msg.STEP_STATE)
	assert_array(sent).is_empty()
	assert_bool(world.debug_explorer().debugger_state().step_state.paused).is_true()


func test_subscription_does_not_replay_step_state():
	world.debug_pause()
	_captured = []

	ECS._on_debugger_message("subscribe", [{}, 10.0])

	assert_int(_messages(GECSEditorDebuggerMessages.Msg.STEP_STATE).size()).is_equal(0)
	assert_int(_messages(GECSEditorDebuggerMessages.Msg.WORLD_INIT).size()).is_equal(0)
