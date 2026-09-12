extends GdUnitTestSuite

func test_compact_tab_only_contains_transport_logs_and_breakpoints() -> void:
	var tab = auto_free(preload("res://addons/gecs/debug/gecs_editor_debugger_tab.tscn").instantiate())
	add_child(tab)
	assert_int(tab.step_panel.tabs.get_tab_count()).is_equal(2)
	assert_str(tab.step_panel.tabs.get_tab_title(0)).contains("Step log")
	assert_object(tab.find_child("EntitiesTree", true, false)).is_null()
	assert_object(tab.find_child("CaptureSettings", true, false)).is_null()

func test_system_digest_reconciles_rows_and_preserves_identity_and_selection() -> void:
	var model := GECSExplorerModel.new()
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	workspace._systems({1: {"path": "Move", "last_run_data": {"execution_time_ms": 2.0}}, 2: {"path": "Render", "last_run_data": {"execution_time_ms": 1.0}}})
	var retained: TreeItem = workspace._system_items[1]
	retained.select(0)
	workspace._systems({1: {"path": "Move", "paused": true, "last_run_data": {"execution_time_ms": 0.0}}, 3: {"path": "Spawn"}})
	assert_object(workspace._system_items[1]).is_same(retained)
	assert_object(workspace.systems_tree.get_selected()).is_same(retained)
	assert_bool(workspace._system_items.has(2)).is_false()
	assert_int(workspace._system_items.size()).is_equal(2)
	assert_str(retained.get_text(9)).is_equal("Paused")

func test_poll_interests_follow_visibility_including_detached_entity_views() -> void:
	var model := GECSExplorerModel.new()
	model.connected = true
	model.world_id = 10
	model.epoch = 1
	model.sender = func(_message, _args): return true
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	workspace.open_entity({"world": 10, "epoch": 1, "id": 1, "iid": 100})
	var view: GECSExplorerEntityView = workspace.active_view()
	workspace.hide()
	assert_array(workspace._poll_requests()).is_empty()
	var window = auto_free(Window.new())
	add_child(window)
	view.reparent(window)
	window.show()
	var polls: Array = workspace._poll_requests()
	assert_bool(polls.any(func(poll): return poll.op == "sample")).is_true()
	window.hide()
	assert_array(workspace._poll_requests()).is_empty()

func test_browser_response_reconciles_removed_entities_without_losing_selection() -> void:
	var model := GECSExplorerModel.new()
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	var first := {"name": "First", "enabled": true, "identity": {"iid": 1}, "values": {}}
	var second := {"name": "Second", "enabled": false, "identity": {"iid": 2}, "values": {}}
	workspace._finished("query", {"rows": [first, second], "total": 2, "page": 0}, {"key": "browser"})
	workspace.browser.get_root().get_first_child().select(0)
	workspace._finished("query", {"rows": [first], "total": 1, "page": 0}, {"key": "browser"})
	assert_int(workspace.browser.get_selected().get_metadata(0).iid).is_equal(1)
	assert_bool(model.entities.has(2)).is_false()

func test_native_windows_poll_only_displayed_content_after_focus_loss() -> void:
	var model := GECSExplorerModel.new()
	model.connected = true
	model.world_id = 10
	model.epoch = 1
	model.sender = func(_message, _args): return true
	var host = auto_free(preload("res://addons/gecs/debug/explorer/gecs_explorer_host.gd").new())
	add_child(host)
	host.hide() # The real editor keeps this owner hidden.
	var workspace := GECSExplorerWorkspace.new()
	workspace.configure(model)
	host.sessions.add_child(workspace)
	host.open_window()
	workspace.open_entity({"world": 10, "epoch": 1, "id": 1, "iid": 100})
	var first: GECSExplorerEntityView = workspace.active_view()
	workspace.open_entity({"world": 10, "epoch": 1, "id": 2, "iid": 200})
	var second: GECSExplorerEntityView = workspace.active_view()
	host.window.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var polls: Array = workspace._poll_requests()
	var samples: Array = polls.filter(func(poll): return poll.op == "sample")
	assert_int(samples.size()).is_equal(1)
	assert_array(samples[0].args.keys).contains_exactly([second._watch_key])
	assert_bool(polls.any(func(poll): return poll.op in ["systems", "overview", "graph"])).is_false()
	# A detached window continues consuming even when its original tab and
	# the companion window are hidden. Other entity tabs remain idle.
	workspace._detach(second)
	host.hide_window()
	var detached_window: Window = second.get_window()
	assert_bool(detached_window.force_native).is_true()
	detached_window.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	polls = workspace._poll_requests()
	assert_int(polls.size()).is_equal(1)
	assert_array(polls[0].args.keys).contains_exactly([second._watch_key])
	assert_bool(GECSExplorerWorkspace._visible(first)).is_false()
	detached_window.hide()
	assert_array(workspace._poll_requests()).is_empty()
	# A graph can be displayed independently of its hidden entity inspector.
	first.graph_toggle.button_pressed = true
	first.graph_panel.show_live_check.button_pressed = true
	first._open_graph_window()
	first._graph_window.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	polls = workspace._poll_requests()
	assert_int(polls.size()).is_equal(1)
	assert_str(polls[0].op).is_equal("graph")
	assert_int(polls[0].args.id).is_equal(first.graph_id)
	first.graph_panel.show_live_check.button_pressed = false
	assert_array(workspace._poll_requests()).is_empty()

func test_hidden_tabs_do_not_poll_but_selected_systems_do() -> void:
	var model := GECSExplorerModel.new()
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	workspace.nav.current_tab = 3 # Systems
	assert_array(workspace._poll_requests()).contains_exactly([{"op": "systems"}])
	workspace.nav.current_tab = 1 # One-shot queries
	assert_array(workspace._poll_requests()).is_empty()

func test_explorer_exposes_breakpoint_management_and_system_toggle_actions() -> void:
	var model := GECSExplorerModel.new()
	var sent: Array = []
	model.sender = func(message, data): sent.append([message, data]); return true
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	var panel: GECSEditorStepPanel = workspace.transport
	assert_bool(panel.tabs.visible).is_false()
	panel.manage_breakpoints_btn.pressed.emit()
	assert_bool(panel.breakpoints_popup.visible).is_true()
	assert_bool(panel.bp_box.is_visible_in_tree()).is_true()
	panel.breakpoints_popup.hide()
	workspace._systems({42: {"path": "Movement"}})
	workspace._system_items[42].select(0)
	assert_bool(workspace._system_context_actions().has("Break before system")).is_true()
	workspace._system_action("break")
	assert_array(sent).contains_exactly([["gecs:breakpoint_add", [{"kind": "system", "system_id": 42}]]])
	sent.clear()
	model.step_state = {"breakpoints": [{"id": 7, "system_id": 42, "enabled": true}, {"id": 8, "system_id": 42, "enabled": true}]}
	workspace._refresh_transport()
	assert_bool(workspace._system_context_actions().has("Disable system breakpoint")).is_true()
	assert_str(workspace._system_items[42].get_text(9)).contains("Breakpoint armed")
	workspace._system_action("break")
	assert_array(sent).contains_exactly([["gecs:breakpoint_set_enabled", [7, false]], ["gecs:breakpoint_set_enabled", [8, false]]])
	for bp in model.step_state.breakpoints: bp.enabled = false
	workspace._refresh_transport()
	assert_str(workspace._system_break_button.text).is_equal("Enable system breakpoint")
	assert_str(workspace._system_items[42].get_text(9)).contains("Breakpoint disabled")
	sent.clear()
	workspace._system_action("break")
	assert_array(sent).contains_exactly([["gecs:breakpoint_set_enabled", [7, true]]])
	sent.clear()
	workspace._system_action("remove_break")
	assert_array(sent).contains_exactly([["gecs:breakpoint_remove", [7]], ["gecs:breakpoint_remove", [8]]])
