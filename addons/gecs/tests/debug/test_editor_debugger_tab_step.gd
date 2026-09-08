## Headless coverage for the debugger tab's step debugger and graph panes:
## message handlers are called directly, the way the transport would deliver
## them, and the resulting tree rows / graph nodes are asserted.
extends GdUnitTestSuite

const TAB_SCENE := "res://addons/gecs/debug/gecs_editor_debugger_tab.tscn"


func _make_tab() -> GECSEditorDebuggerTab:
	var tab = auto_free(load(TAB_SCENE).instantiate())
	add_child(tab)
	return tab


func _count_rows(tree: Tree) -> int:
	var root = tree.get_root()
	if root == null:
		return 0
	var count := 0
	var child = root.get_first_child()
	while child:
		count += 1
		child = child.get_next()
	return count


func _state(overrides: Dictionary = {}) -> Dictionary:
	var state := {
		"paused": true,
		"cursor": {
			"has_group": true,
			"group": "",
			"slot": 1,
			"system_id": 0,
			"system_name": "",
			"in_system": false,
			"unit_index": 0,
			"unit_count": 0,
			"unit_label": "",
			"next_label": "",
		},
		"step_entities": [],
		"sweep_enabled": true,
		"breakpoints": [],
		"graph_watch": [],
		"graph_depth": 0,
		"step_counter": 0,
		"pending_requests": 0,
		"frame_step_active": false,
		"break_info": {},
	}
	for key in overrides:
		if key == "cursor":
			state.cursor.merge(overrides.cursor, true)
		else:
			state[key] = overrides[key]
	return state


func _log(overrides: Dictionary = {}) -> Dictionary:
	var log := {
		"step_id": 1,
		"kind": GECSStepper.Kind.SYSTEM,
		"kind_name": "system",
		"label": "S1",
		"frame": 3,
		"group": "",
		"system_id": 0,
		"systems": ["S1"],
		"skipped": [],
		"ops": [],
		"op_count": 0,
		"truncated": false,
		"ms": 0.5,
		"touched": [],
		"break_info": {},
	}
	for key in overrides:
		log[key] = overrides[key]
	log["op_count"] = log.ops.size()
	return log


func _add_system(tab: GECSEditorDebuggerTab, system_id: int, name: String) -> void:
	tab.system_added(system_id, "", false, true, false, NodePath("res://" + name + ".gd"))
	tab.system_last_run_data(system_id, name, {"execution_time_ms": 0.1, "execution_order": 0})


func _graph(entity_ids: Array, edges: Array) -> Dictionary:
	var nodes := []
	for iid in entity_ids:
		nodes.append(
			{
				"key": "e:%d" % iid,
				"kind": "entity",
				"instance_id": iid,
				"id": iid,
				"name": "e%d" % iid,
				"path": "",
				"enabled": true,
				"watched": iid == entity_ids[0],
				"stub": false,
				"dangling": 0,
				"components": [{"id": iid * 10, "type": "C_TestA", "data": {"value": iid}}],
			}
		)
	var edge_dicts := []
	for i in edges.size():
		var pair: Array = edges[i]
		edge_dicts.append(
			{
				"key": "r:%d" % (1000 + i),
				"rel_id": 1000 + i,
				"from": "e:%d" % pair[0],
				"to": "e:%d" % pair[1],
				"relation_type": "res://c_likes.gd",
				"relation_data": {},
				"target_type": "Entity",
				"target_data": {"id": pair[1], "path": "/root/e%d" % pair[1]},
			}
		)
	return {"watched": [entity_ids[0]], "nodes": nodes, "edges": edge_dicts}


func test_tab_scene_loads_with_step_and_graph_panes() -> void:
	var tab := _make_tab()
	assert_object(tab.step_panel).is_not_null()
	assert_object(tab.graph_panel).is_not_null()
	assert_int(tab.system_tree.columns).is_equal(10)
	assert_int(tab.entities_tree.select_mode).is_equal(Tree.SELECT_MULTI)
	assert_object(tab.step_panel.log_tree).is_not_null()
	assert_object(tab.step_panel.breakpoints_tree).is_not_null()
	assert_int(tab.step_panel.step_buttons.size()).is_equal(5)
	assert_object(tab.graph_panel.graph).is_not_null()
	assert_bool(tab.step_panel.pause_btn.disabled).is_false()
	assert_bool(tab.step_panel.resume_btn.disabled).is_true()


func test_step_state_marks_cursor_row_and_breakpoint_checkbox() -> void:
	var tab := _make_tab()
	_add_system(tab, 7, "S7")
	_add_system(tab, 8, "S8")

	tab.step_state(
		_state(
			{
				"cursor": {"system_id": 7, "system_name": "S7"},
				"breakpoints": [
					{"id": 3, "kind": GECSStepper.BpKind.SYSTEM, "kind_name": "system", "system_id": 8, "enabled": true, "label": "before S8", "hits": 0}
				],
			}
		)
	)

	var row7: TreeItem = tab._find_system_item(7)
	var row8: TreeItem = tab._find_system_item(8)
	assert_str(row7.get_text(8)).is_not_empty()
	assert_str(row8.get_text(8)).is_empty()
	assert_bool(row8.is_checked(9)).is_true()
	assert_bool(row7.is_checked(9)).is_false()
	assert_bool(tab.step_panel.paused).is_true()
	assert_bool(tab.step_panel.pause_btn.disabled).is_true()
	assert_bool(tab.step_panel.resume_btn.disabled).is_false()
	assert_str(tab.step_panel.status_label.text).contains("S7")
	assert_int(_count_rows(tab.step_panel.breakpoints_tree)).is_equal(1)

	# Cursor moves: exactly one marker at a time.
	tab.step_state(_state({"cursor": {"system_id": 8, "system_name": "S8"}}))
	assert_str(row7.get_text(8)).is_empty()
	assert_str(row8.get_text(8)).is_not_empty()
	assert_bool(row8.is_checked(9)).is_false()

	# A later last_run_data refresh keeps the marker.
	tab.system_last_run_data(8, "S8", {"execution_time_ms": 0.2, "execution_order": 1})
	assert_str(tab._find_system_item(8).get_text(8)).is_not_empty()


func test_step_log_appends_rows_with_op_children_and_caps() -> void:
	var tab := _make_tab()
	var ops := [
		[GECSStepper.Op.PROP_SET, 1, "e1", "C_TestPosition", "position", Vector3.ZERO, Vector3.ONE, "", "S1"],
		[GECSStepper.Op.COMP_ADD, 1, "e1", "C_TestB", 55, null, null, "cmd", "S1"],
		[GECSStepper.Op.SWEEP_SET, 1, "e1", "C_TestA", "value", 0, 1, "(sweep)", ""],
	]
	tab.step_log(_log({"ops": ops, "skipped": ["S0"]}))

	var log_tree: Tree = tab.step_panel.log_tree
	assert_int(_count_rows(log_tree)).is_equal(1)
	var row: TreeItem = log_tree.get_root().get_first_child()
	assert_str(row.get_text(1)).is_equal("S1")
	assert_str(row.get_text(3)).is_equal("3")
	var children := 0
	var child := row.get_first_child()
	while child:
		children += 1
		child = child.get_next()
	assert_int(children).is_equal(4)  # skipped row + 3 ops
	var first_op: TreeItem = row.get_first_child().get_next()
	assert_str(first_op.get_text(1)).contains("prop_set e1#1")
	assert_str(first_op.get_text(2)).is_equal("C_TestPosition.position")
	assert_str(first_op.get_text(4)).contains("S1")

	for i in range(2, 206):
		tab.step_log(_log({"step_id": i}))
	assert_int(_count_rows(log_tree)).is_equal(GECSEditorStepPanel.MAX_LOG_ENTRIES)
	assert_int(tab.step_panel.logs.size()).is_equal(GECSEditorStepPanel.MAX_LOG_ENTRIES)


func test_step_log_tints_touched_rows_and_clears_on_the_next_log() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/e1"))
	tab.entity_added(2, NodePath("/root/e2"))
	_add_system(tab, 7, "S7")

	tab.step_log(_log({"touched": [1], "system_id": 7}))
	var e1: TreeItem = tab._find_entity_item(1)
	var e2: TreeItem = tab._find_entity_item(2)
	assert_that(e1.get_custom_bg_color(0)).is_equal(tab.STEP_HIGHLIGHT_COLOR)
	assert_that(e2.get_custom_bg_color(0)).is_not_equal(tab.STEP_HIGHLIGHT_COLOR)
	assert_that(tab._find_system_item(7).get_custom_bg_color(0)).is_equal(tab.STEP_HIGHLIGHT_COLOR)

	tab.step_log(_log({"step_id": 2, "touched": [2], "system_id": 0}))
	assert_that(e1.get_custom_bg_color(0)).is_not_equal(tab.STEP_HIGHLIGHT_COLOR)
	assert_that(e2.get_custom_bg_color(0)).is_equal(tab.STEP_HIGHLIGHT_COLOR)
	assert_that(tab._find_system_item(7).get_custom_bg_color(0)).is_not_equal(tab.STEP_HIGHLIGHT_COLOR)


func test_break_and_external_entries_are_rendered() -> void:
	var tab := _make_tab()
	tab.step_log(
		_log(
			{
				"kind": -1,
				"kind_name": "break",
				"label": "break: Adder",
				"break_info": {"breakpoint_id": 1, "label": "C_TestB added", "op": "comp_add", "entity_id": 1, "entity_name": "e1", "system": "Adder"},
			}
		)
	)
	tab.step_log(_log({"step_id": 2, "kind": -1, "kind_name": "external", "label": "(external)"}))

	var root: TreeItem = tab.step_panel.log_tree.get_root()
	var brk: TreeItem = root.get_first_child()
	assert_str(brk.get_text(2)).is_equal("break")
	assert_str(brk.get_first_child().get_text(1)).is_equal("breakpoint hit")
	assert_that(brk.get_custom_color(1)).is_equal(GECSEditorStepPanel.COLOR_BREAK)
	assert_str(brk.get_next().get_text(2)).is_equal("external")


func test_clear_all_data_resets_step_and_graph_panes() -> void:
	var tab := _make_tab()
	_add_system(tab, 7, "S7")
	tab.step_state(_state({"cursor": {"system_id": 7}}))
	tab.step_log(_log({"touched": [], "system_id": 7}))
	tab.graph_state(1, _graph([1, 2], [[1, 2]]))

	tab.clear_all_data()

	assert_int(_count_rows(tab.step_panel.log_tree)).is_equal(0)
	assert_int(_count_rows(tab.step_panel.breakpoints_tree)).is_equal(0)
	assert_bool(tab.step_panel.paused).is_false()
	assert_int(tab._step_cursor_system_id).is_equal(0)
	assert_int(tab.graph_panel._nodes.size()).is_equal(0)
	assert_int(tab.graph_panel.graph.get_connection_list().size()).is_equal(0)


func test_graph_state_creates_nodes_and_connections() -> void:
	var tab := _make_tab()

	tab.graph_state(1, _graph([1, 2, 3], [[1, 2], [1, 3]]))

	var panel: GECSEditorGraphPanel = tab.graph_panel
	assert_int(panel._nodes.size()).is_equal(3)
	assert_int(panel.graph.get_connection_list().size()).is_equal(2)
	assert_array(panel.watch_ids).is_equal([1])
	var watched: GraphNode = panel._nodes["e:1"]
	assert_str(watched.title).contains("[watched]")
	assert_bool(watched.is_slot_enabled_left(0)).is_true()
	# Two outgoing edges = two right ports on the watched node.
	assert_bool(watched.is_slot_enabled_right(1)).is_false()  # component row
	assert_bool(watched.is_slot_enabled_right(2)).is_true()
	assert_bool(watched.is_slot_enabled_right(3)).is_true()


func test_graph_update_preserves_positions_and_removes_stale_nodes() -> void:
	var tab := _make_tab()
	tab.graph_state(1, _graph([1, 2, 3], [[1, 2], [1, 3]]))
	var panel: GECSEditorGraphPanel = tab.graph_panel
	var moved: GraphNode = panel._nodes["e:2"]
	moved.position_offset = Vector2(999, 123)

	tab.graph_state(2, _graph([1, 2], [[1, 2]]))

	assert_int(panel._nodes.size()).is_equal(2)
	assert_bool(panel._nodes.has("e:3")).is_false()
	assert_object(panel._nodes["e:2"]).is_same(moved)
	assert_that(moved.position_offset).is_equal(Vector2(999, 123))
	assert_int(panel.graph.get_connection_list().size()).is_equal(1)


func test_multiple_relationships_between_the_same_pair_render_separately() -> void:
	var tab := _make_tab()

	tab.graph_state(1, _graph([1, 2], [[1, 2], [1, 2]]))

	assert_int(tab.graph_panel.graph.get_connection_list().size()).is_equal(2)


func test_step_log_highlights_graph_nodes_and_added_edges() -> void:
	var tab := _make_tab()
	tab.graph_state(1, _graph([1, 2], [[1, 2]]))
	var panel: GECSEditorGraphPanel = tab.graph_panel

	tab.step_log(
		_log(
			{
				"touched": [1],
				"ops": [[GECSStepper.Op.REL_ADD, 1, "e1", "C_Likes", "Entity e2", 1000, 2, "", "S1"]],
			}
		)
	)
	assert_bool(panel._nodes["e:1"].has_theme_stylebox_override("titlebar")).is_true()
	assert_bool(panel._nodes["e:2"].has_theme_stylebox_override("titlebar")).is_false()

	tab.step_log(_log({"step_id": 2, "touched": [2]}))
	assert_bool(panel._nodes["e:1"].has_theme_stylebox_override("titlebar")).is_false()
	assert_bool(panel._nodes["e:2"].has_theme_stylebox_override("titlebar")).is_true()


func test_selected_entity_ids_reads_multi_selection() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/e1"))
	tab.entity_added(2, NodePath("/root/e2"))
	tab.entity_component_added(1, 10, "C_TestA", {"value": 1})
	var e1: TreeItem = tab._find_entity_item(1)
	var e2: TreeItem = tab._find_entity_item(2)
	e1.select(0)
	e2.select(0)
	e1.get_first_child().select(0)  # component row must be ignored

	assert_array(tab.get_selected_entity_ids()).contains_exactly_in_any_order([1, 2])
