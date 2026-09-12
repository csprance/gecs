## Headless coverage for the debugger tab's step debugger pane and graph windows:
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
		"graphs": {},
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


func test_break_notice_names_cause_and_disables_only_the_hit_breakpoint() -> void:
	var tab := _make_tab()
	var panel := tab.step_panel
	var sent: Array = []
	panel.send = func(message, data): sent.append([message, data]); return true
	var state := _state({
		"break_info": {"breakpoint_id": 7, "label": "before Movement", "system": "Movement"},
		"breakpoints": [{"id": 7, "enabled": true, "label": "before Movement"}, {"id": 8, "enabled": true, "label": "before Render"}]
	})
	panel.apply_state(state)
	assert_bool(panel.break_notice.visible).is_true()
	assert_str(panel.break_reason.text).contains("System: Movement")
	assert_str(panel.break_reason.text).contains("breakpoint #7")
	assert_str(panel.break_reason.text).contains("Resume keeps this breakpoint armed")
	panel.breakpoints_tree.get_root().get_first_child().select(0)
	panel.apply_state(state)
	assert_int(panel.breakpoints_tree.get_selected().get_meta("bp_id")).is_equal(7)
	panel.remove_breakpoint_btn.pressed.emit()
	assert_array(sent).contains_exactly([["gecs:breakpoint_remove", [7]]])
	sent.clear()
	panel.disable_break_btn.pressed.emit()
	assert_array(sent).contains_exactly([["gecs:breakpoint_set_enabled", [7, false]]])
	state.breakpoints[0].enabled = false
	panel.apply_state(state)
	assert_bool(panel.disable_break_btn.visible).is_false()
	assert_str(panel.break_reason.text).contains("disabled. Press Resume")
	state.breakpoints.remove_at(0)
	panel.apply_state(state)
	assert_str(panel.break_reason.text).contains("removed. Press Resume")
	state.paused = false
	panel.apply_state(state)
	assert_bool(panel.break_notice.visible).is_false()
	panel.clear()
	assert_bool(panel.break_notice.visible).is_false()


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


func test_selected_step_kind_and_count_are_sent() -> void:
	var tab := _make_tab()
	var sent: Array = []
	tab.step_panel.send = func(message: String, data: Array):
		sent.append([message, data])
		return true
	tab.step_panel.step_kind.select(GECSStepper.Kind.ENTITY)
	tab.step_panel.count_spin.value = 3
	assert_str(tab.step_panel.step_btn.text).is_equal("Step ×3")
	tab.step_panel.step_btn.pressed.emit()
	assert_array(sent).is_equal([["gecs:step", [GECSStepper.Kind.ENTITY, 3]]])


func test_reset_restores_sweep_and_empty_log_and_breakpoint_tab_title() -> void:
	var tab := _make_tab()
	tab.step_state(_state({"sweep_enabled": false, "breakpoints": [
		{"id": 1, "kind_name": "entity", "label": "e1", "enabled": true}
	]}))
	assert_str(tab.step_panel.tabs.get_tab_title(1)).is_equal("Breakpoints (1)")
	tab.step_log(_log())
	assert_bool(tab.step_panel.clear_log_btn.disabled).is_false()
	tab.clear_all_data()
	assert_bool(tab.step_panel.sweep_check.button_pressed).is_true()
	assert_bool(tab.step_panel.clear_log_btn.disabled).is_true()
	assert_str(tab.step_panel.tabs.get_tab_title(1)).is_equal("Breakpoints")
	assert_str(tab.step_panel.log_hint.text).contains("No steps yet")
