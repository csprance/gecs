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
