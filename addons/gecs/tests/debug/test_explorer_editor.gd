extends GdUnitTestSuite

const ExplorerHost = preload("res://addons/gecs/debug/explorer/gecs_explorer_host.gd")

func _model() -> GECSExplorerModel:
	var model := GECSExplorerModel.new()
	model.connected = true
	model.sender = func(_message: String, _data: Array): return true
	return model

func test_connection_status_survives_session_end_and_activity_lives_above_navigation() -> void:
	var model := _model()
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	var hello := model.request("hello")
	model.accept({"request_id": hello, "world": 10, "epoch": 1, "result": {"world_path": "/root/World", "step_state": {"paused": false}}})
	assert_str(workspace.transport.status_label.text).contains("Connected")
	workspace.open_entity({"world": 10, "epoch": 1, "id": 1, "iid": 100})
	var view: GECSExplorerEntityView = workspace.active_view()
	model.step_state.paused = true
	model.updated.emit("step", model.step_state)
	assert_str(workspace.transport.status_label.text).contains("ECS paused")
	model.script_breaked = true
	model.updated.emit("step", model.step_state)
	assert_str(workspace.transport.status_label.text).contains("Godot break")
	model.disconnect_session()
	assert_str(workspace.transport.status_label.text).contains("Session ended")
	assert_str(workspace.status.text).contains("frozen")
	assert_str(workspace.session_label.text).is_equal("/root/World")
	assert_str(view._live_hint.text).contains("FROZEN DATA")
	workspace.status.text = "Another action"
	workspace._process(0.0)
	assert_str(workspace.transport.status_label.text).contains("Session ended")
	assert_int(workspace.status.get_parent().get_parent().get_index()).is_less(workspace.nav.get_index())
	for i in 60:
		workspace.status.text = str(i)
		workspace._process(0.0)
	assert_int(workspace._status_history.size()).is_equal(50)

func test_snapshot_responses_are_ordered_and_disconnected_restore_sends_nothing() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var received: Array = []
	model.request_finished.connect(func(_op, result, _context): received.append(result))
	var first := model.request("snapshot_preview")
	var second := model.request("snapshot_preview")
	model.accept({"request_id": second, "world": 10, "epoch": 1, "result": {"token": 2}})
	model.accept({"request_id": first, "world": 10, "epoch": 1, "result": {"token": 1}})
	assert_int(received.size()).is_equal(1)
	assert_int(received[0].token).is_equal(2)
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	model.disconnect_session()
	var sent: Array = []
	model.sender = func(_message, args): sent.append(args); return true
	workspace._restore_dialog.confirmed.emit()
	assert_array(sent).is_empty()

func test_snapshot_file_roundtrip_only_previews_and_drafts_block_confirmation() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	model.step_state = {"paused": true}
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	var path := "user://gecs_snapshot_test_%d.gecs-state.json" % Time.get_ticks_usec()
	var saved := {"format": "gecs-explorer-snapshot", "version": 1, "entities": [], "source": "must never execute"}
	workspace._snapshot_data = saved.duplicate(true)
	workspace._snapshot_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	workspace._snapshot_file_selected(path)
	var loaded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_str(loaded.format).is_equal(saved.format)
	assert_str(loaded.source).is_equal(saved.source)
	assert_int(int(loaded.version)).is_equal(1)
	assert_array(loaded.entities).is_empty()
	var sent: Array = []
	model.sender = func(_message, args): sent.append(args[0]); return true
	workspace._snapshot_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	workspace._snapshot_file_selected(path)
	DirAccess.remove_absolute(path)
	assert_int(sent.size()).is_equal(1)
	assert_str(sent[0].op).is_equal("snapshot_preview")
	workspace.open_entity({"world": 10, "epoch": 1, "id": 1, "iid": 100})
	var view: GECSExplorerEntityView = workspace.active_view()
	view.drafts.append({"op": "enabled", "value": false})
	sent.clear()
	workspace._restore_dialog.confirmed.emit()
	assert_array(sent).is_empty()
	assert_str(workspace.status.text).contains("local drafts")

func test_workspace_loads_with_native_navigation_and_no_graphs() -> void:
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(_model())
	add_child(workspace)
	assert_int(workspace.nav.get_tab_count()).is_equal(5)
	assert_str(workspace.nav.get_tab_title(0)).is_equal("Explore")
	assert_int(workspace.views.size()).is_equal(0)
	assert_bool(workspace.transport.tabs.visible).is_false()
	assert_str(workspace.entity_tabs.get_tab_title(0)).is_equal("World")

func test_overview_stays_available_and_only_polls_when_visible() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	get_tree().root.add_child(workspace)
	workspace.set_process(false)
	await get_tree().process_frame
	assert_bool(workspace.overview.is_visible_in_tree()).is_true()
	assert_bool(workspace._poll_requests().any(func(poll): return poll.op == "overview")).is_true()
	workspace.open_entity({"world": 10, "epoch": 1, "id": 1, "iid": 100})
	assert_bool(workspace.entity_tabs.is_tab_hidden(0)).is_false()
	assert_bool(workspace._poll_requests().any(func(poll): return poll.op == "overview")).is_false()
	workspace.entity_tabs.current_tab = 0
	assert_bool(workspace._poll_requests().any(func(poll): return poll.op == "overview")).is_true()
	assert_int(workspace.entity_tabs.get_tab_bar().tab_close_display_policy).is_equal(TabBar.CLOSE_BUTTON_SHOW_NEVER)
	model.disconnect_session()
	assert_str(workspace.overview._note.text).contains("Session ended")

func test_overview_retention_drilldown_and_new_world_reset() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	workspace.overview.load_preferences({})
	var path := "res://addons/gecs/tests/components/c_test_a.gd"
	var data := {"time": 0, "entities": 5, "enabled": 4, "components": 5, "component_types": 1, "relationships": 0, "relationship_types": 0, "systems": 0, "active_systems": 0, "observers": 0, "archetypes": 1, "cached_queries": 0, "system_ms": null, "collection_ms": 0.1, "component_rows": [{"name": "C_TestA", "script": path, "count": 5}], "relationship_rows": [], "system_rows": []}
	for i in 130:
		data.time = i * 1000
		workspace.overview.apply(data)
	assert_int(workspace.overview.history.size()).is_equal(120)
	var tree: Tree = workspace.overview.component_tree
	var row := tree.get_root().get_first_child()
	row.select(0)
	data.time += 1000
	workspace.overview.apply(data)
	assert_object(tree.get_selected()).is_same(row)
	var requests: Array = []
	model.sender = func(_message, args): requests.append(args[0]); return true
	tree.item_activated.emit()
	assert_int(workspace.nav.current_tab).is_equal(1)
	assert_str(requests.back().op).is_equal("query")
	assert_array(requests.back().args.spec.all).contains_exactly([path])
	data.time += 10000
	workspace.overview.apply(data)
	assert_int(workspace.overview.history.size()).is_equal(1)
	model.updated.emit("world_changed", {})
	assert_array(workspace.overview.history).is_empty()
	assert_str(workspace.overview.metrics.Entities.text).is_equal("—")

func _overview_sample(time: int) -> Dictionary:
	return {"time": time, "entities": 5, "enabled": 4, "components": 5, "component_types": 2, "relationships": 0, "relationship_types": 0, "systems": 0, "active_systems": 0, "observers": 0, "archetypes": 1, "cached_queries": 0, "system_ms": null, "collection_ms": 0.1, "component_rows": [{"name": "A", "script": "a.gd", "count": 3}, {"name": "B", "script": "b.gd", "count": 2}], "relationship_rows": [], "system_rows": []}

func test_dashboard_options_retain_history_and_import_without_actions() -> void:
	var dashboard = auto_free(GECSExplorerWorkspace.Overview.new())
	add_child(dashboard)
	var actions: Array = []
	dashboard.preferences_changed.connect(func(): actions.append("save"))
	dashboard.refresh_requested.connect(func(): actions.append("refresh"))
	dashboard.load_preferences({"interval_ms": 500, "window_seconds": 120, "row_limit": 24, "chart_keys": ["components", "system_ms"]})
	for i in 260: dashboard.apply(_overview_sample(i * 500))
	assert_int(dashboard.history.size()).is_equal(240)
	dashboard.load_preferences({"interval_ms": 500, "window_seconds": 30, "chart_keys": ["components", "system_ms"]})
	assert_int(dashboard._entity_chart.values.size()).is_equal(60)
	assert_int(dashboard.history.size()).is_equal(240)
	assert_int(dashboard.samples_csv().split("\n").size()).is_equal(61)
	assert_bool(dashboard.samples_csv().contains("<null>")).is_false()
	dashboard.load_preferences({"interval_ms": 500, "window_seconds": 120})
	assert_int(dashboard._entity_chart.values.size()).is_equal(240)
	assert_array(actions).is_empty()
	dashboard.load_preferences({"interval_ms": {}, "row_limit": 100000, "chart_keys": ["invalid", null]})
	assert_int(dashboard.interval_ms).is_equal(1000)
	assert_int(dashboard.row_limit).is_equal(12)
	assert_bool(dashboard.frozen).is_false()

func test_dashboard_freeze_blocks_polling_but_manual_refresh_is_explicit() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	get_tree().root.add_child(workspace)
	workspace.overview.load_preferences({})
	workspace.set_process(false)
	await get_tree().process_frame
	var requests: Array = []
	model.sender = func(_message, args): requests.append(args[0]); return true
	workspace.overview._freeze_button.button_pressed = true
	workspace._overview_last_pull = -10000
	workspace._process(0)
	assert_array(requests).is_empty()
	workspace.overview.apply(_overview_sample(0))
	assert_array(workspace.overview.history).is_empty()
	workspace.overview._refresh_button.pressed.emit()
	assert_int(requests.size()).is_equal(1)
	assert_str(requests[0].op).is_equal("overview")
	assert_int(requests[0].args.limit).is_equal(12)
	workspace._finished("overview", _overview_sample(1000), {})
	assert_int(workspace.overview.history.size()).is_equal(1)
	assert_bool(workspace.overview.frozen).is_true()
	assert_bool(model.step_state.get("paused", false)).is_false()

func test_dashboard_rows_keep_identity_when_costs_reorder_and_sort_is_explicit() -> void:
	var dashboard = auto_free(GECSExplorerWorkspace.Overview.new())
	add_child(dashboard)
	var data := _overview_sample(0)
	dashboard.apply(data)
	var tree: Tree = dashboard.component_tree
	var a := tree.get_root().get_first_child()
	a.select(0)
	data.time = 1000
	data.component_rows[1].count = 10
	dashboard.apply(data)
	assert_object(tree.get_selected()).is_same(a)
	assert_str(tree.get_root().get_first_child().get_text(0)).is_equal("B")
	tree.column_title_clicked.emit(0)
	assert_object(tree.get_root().get_first_child()).is_same(a)
	assert_object(tree.get_selected()).is_same(a)
	data.component_rows.remove_at(0)
	dashboard.apply(data)
	assert_object(tree.get_selected()).is_null()

func test_chart_hover_uses_sample_times_instead_of_equal_spacing() -> void:
	var chart = auto_free(GECSExplorerChart.new())
	add_child(chart)
	chart.values = [10, 20, 30]
	chart.sample_times = [0, 100, 1000]
	chart.duration = 1.0
	chart.size = Vector2(400, 165)
	chart.show_hover = true
	assert_float(chart._sample_fraction(1)).is_equal(0.1)
	var point := Vector2(32 + (400 - 34) * 0.1, 60)
	assert_int(chart._index_at(point)).is_equal(1)
	assert_str(chart._get_tooltip(point)).contains("20")
	assert_str(chart._get_tooltip(point)).contains("0.90s")

func test_session_models_discard_stale_and_out_of_order_replies() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var replies: Array = []
	model.request_finished.connect(func(_op, result, _context): replies.append(result))
	var first := model.request("query", {}, {"key": "results"})
	var second := model.request("query", {}, {"key": "results"})
	model.accept({"request_id": second, "world": 10, "epoch": 1, "result": {"total": 2}})
	model.accept({"request_id": first, "world": 10, "epoch": 1, "result": {"total": 1}})
	assert_int(replies.size()).is_equal(1)
	assert_int(replies[0].total).is_equal(2)
	var stale := model.request("inspect")
	model.accept({"request_id": stale, "world": 11, "epoch": 1, "result": {}})
	assert_int(replies.size()).is_equal(2)
	assert_bool(replies.back().has("error")).is_true()
	assert_int(model.world_id).is_equal(0)

func test_charts_retain_at_most_600_samples_and_reject_old_events() -> void:
	var model := _model()
	model.world_id = 1
	model.epoch = 1
	model.watches["x"] = {}
	for i in 650:
		model._accept_sample({"samples": {"x": {}}, "time": i, "step": i})
	assert_int(model.series.x.size()).is_equal(600)
	model.event({"world": 1, "epoch": 1, "sequence": 1, "kind": "sample", "data": {}})
	assert_int(model.series.x.size()).is_equal(600)

func test_import_loads_definitions_without_executing_them() -> void:
	var sent: Array = []
	var model := _model()
	model.sender = func(message, args): sent.append([message, args]); return true
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	sent.clear()
	workspace._load_setup({"queries": {"demo": {"text": "ECS.world.query"}}, "snippets": {"bad": "world.purge()"}, "watches": []})
	assert_array(sent).is_empty()
	assert_str(workspace.saved.snippets.bad).is_equal("world.purge()")

func test_entity_view_opens_and_refresh_keeps_selected_draft() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	var field := {"name": "value", "type": TYPE_INT, "exported": true, "writable": true, "value": GECSExplorerCodec.encode(1)}
	view.snapshot = {"components": [{"iid": 200, "script": "res://subject.gd", "name": "Subject", "fields": [field]}]}
	view._render()
	var row: TreeItem = view.tree.get_root().get_first_child().get_first_child()
	row.select(0)
	view._selected()
	view._stage_property("value", 2)
	field.value = GECSExplorerCodec.encode(3)
	view._render()
	assert_int(view.drafts.size()).is_equal(1)
	assert_int(GECSExplorerCodec.decode(view.drafts[0].value)).is_equal(2)
	assert_str(view.tree.get_selected().get_text(3)).is_equal("Conflict")
	assert_bool(view.chart.visible).is_false()
	assert_bool(view.graph_panel.visible).is_false()
	assert_bool(view._draft_card.visible).is_true()
	assert_bool(view._conflict_actions.visible).is_true()
	assert_str(view._property_title.text).is_equal("Value")
	view.drafts.clear()
	view._render()
	assert_bool(view._draft_card.visible).is_false()
	assert_bool(view._conflict_actions.visible).is_false()
	view.snapshot.components.clear()
	view._render()
	assert_bool(view._property_actions.visible).is_false()
	assert_bool(view.selected.is_empty()).is_true()


func test_query_builder_reports_invalid_input_in_its_own_dialog() -> void:
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(_model())
	add_child(workspace)
	assert_bool(workspace._query_builder_popup.visible).is_false()
	assert_bool(workspace._query_library_popup.visible).is_false()
	assert_bool(workspace._cancel_run.visible).is_false()
	var body: Node = workspace._query_builder_popup.get_child(0)
	for child in body.get_children():
		if child is Button and child.text == "Add property filter": child.pressed.emit()
	assert_bool(workspace._builder_error.visible).is_true()
	assert_str(workspace.query_editor.text).is_equal("ECS.world.query")
	assert_bool(workspace.spec.properties.is_empty()).is_true()


func test_companion_window_retains_drafts_and_subscriptions_when_hidden() -> void:
	var host = auto_free(ExplorerHost.new())
	add_child(host)
	var sent: Array = []
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	model.sender = func(message, args): sent.append([message, args]); return true
	var workspace := GECSExplorerWorkspace.new()
	workspace.configure(model)
	host.sessions.add_child(workspace)
	workspace.query_editor.text = "ECS.world.query.with_all([C_TestA])"
	workspace.open_entity({"world": 10, "epoch": 1, "id": 1, "iid": 100})
	var view := workspace.active_view()
	view.pinned = true
	view.drafts.append({"op": "enabled", "expected": true, "value": false})
	workspace.nav.current_tab = 1
	sent.clear()
	var users := model.watch_users.duplicate(true)
	host.open_window()
	assert_bool(host.window.force_native).is_true()
	assert_bool(host.window.exclusive).is_false()
	assert_bool(host.window.transient).is_false()
	assert_object(host.content.get_parent()).is_same(host.window)
	# Selecting Game hides the main-screen Control; the native window remains.
	host.hide()
	assert_bool(host.window.visible).is_true()
	host.window.close_requested.emit()
	assert_object(host.window).is_not_null()
	assert_bool(host.window.visible).is_false()
	assert_object(host.content.get_parent()).is_same(host.window)
	assert_object(workspace.active_view()).is_same(view)
	assert_int(view.drafts.size()).is_equal(1)
	assert_int(workspace.nav.current_tab).is_equal(1)
	assert_str(workspace.query_editor.text).is_equal("ECS.world.query.with_all([C_TestA])")
	assert_dict(model.watch_users).is_equal(users)
	assert_array(sent).is_empty()


func test_reopening_explorer_focuses_existing_window_and_keeps_sessions() -> void:
	var host = auto_free(ExplorerHost.new())
	add_child(host)
	for i in 2:
		var session := Control.new()
		session.name = "Session %d" % i
		host.sessions.add_child(session)
	host.sessions.current_tab = 1
	host.open_window()
	var first: Window = host.window
	host.open_window()
	assert_bool(host.window.visible).is_true()
	assert_object(host.window).is_same(first)
	assert_int(host.sessions.get_tab_count()).is_equal(2)
	assert_int(host.sessions.current_tab).is_equal(1)
	host.hide_window()
	host.open_window()
	assert_object(host.window).is_same(first)
	assert_int(host.sessions.current_tab).is_equal(1)
	host.hide_window()


func test_entity_tabs_stay_open_and_closing_releases_only_that_watch() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	workspace.open_entity({"world": 10, "epoch": 1, "id": 1, "iid": 100})
	var first: GECSExplorerEntityView = workspace.active_view()
	workspace.open_entity({"world": 10, "epoch": 1, "id": 2, "iid": 101})
	assert_int(workspace.views.size()).is_equal(2)
	assert_int(model.watches.size()).is_equal(2)
	assert_bool(workspace.entity_tabs.tabs_visible).is_true()
	workspace.active_view().drafts.append({"op": "enabled", "value": false})
	workspace._close_active()
	assert_int(workspace.views.size()).is_equal(2)
	workspace.active_view().drafts.clear()
	workspace._close_active()
	assert_int(workspace.views.size()).is_equal(1)
	assert_bool(model.watches.has(first._watch_key)).is_true()
	assert_int(model.watches.size()).is_equal(1)

func test_multiple_charts_share_subscription_and_restore_without_instance_ids() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	var field := {"name": "health", "type": TYPE_INT, "writable": true, "exported": true, "value": GECSExplorerCodec.encode(10)}
	var second := field.duplicate(true)
	second.name = "speed"
	view.snapshot = {"components": [{"iid": 200, "script": "res://subject.gd", "name": "Subject", "fields": [field, second]}]}
	for value in [field, second, field]: view.add_chart({"component": 200, "script": "res://subject.gd", "field": value})
	assert_int(view.chart_properties.size()).is_equal(2)
	assert_int(model.watch_users[view._watch_key]).is_equal(1)
	var layout: Dictionary = view.layout_definition()
	assert_int(layout.charts.size()).is_equal(2)
	assert_bool(layout.charts[0].has("component")).is_false()
	view._clear_charts()
	view.snapshot.components[0].iid = 201
	view.pending_layout = layout
	view._restore_layout()
	assert_int(view.chart_properties.size()).is_equal(2)
	assert_int(view.chart_properties[0].component).is_equal(201)
	view.chart_toggle.button_pressed = false
	view.chart_toggle.button_pressed = true
	assert_bool(view.chart.visible).is_false() # Obsolete single plot stays hidden.
	view._clear_charts()
	view._render() # Removing chart buttons must leave no freed references.

func test_property_proxy_stages_and_authoritative_apply_refreshes_editor() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	var field := {"name": "value", "type": TYPE_INT, "writable": true, "exported": true, "value": GECSExplorerCodec.encode(1)}
	view.snapshot = {"components": [{"iid": 200, "script": "res://subject.gd", "name": "Subject", "fields": [field]}]}
	view._render()
	view.tree.get_root().get_first_child().get_first_child().select(0)
	view._selected()
	view.proxy.set("value", 999)
	assert_bool(view.proxy._dont_undo_redo()).is_true()
	assert_int(view.drafts.size()).is_equal(1)
	assert_bool(view._save_button.disabled).is_false()
	var after: Dictionary = view.snapshot.duplicate(true)
	after.components[0].fields[0].value = GECSExplorerCodec.encode(10)
	view._finished("apply", {"applied": 1, "snapshot": after}, {"key": view._watch_key})
	assert_int(view.proxy.get("value")).is_equal(10)
	assert_bool(view.drafts.is_empty()).is_true()

func test_comparison_replaces_rows_and_keeps_activity_separate() -> void:
	var model := _model()
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	model.captures = [{"entities": {"1": {"enabled": false}}}, {"entities": {"1": {"enabled": true}}}]
	workspace._capture_options()
	workspace._add_change_row("Editor edit", "x", "1", "2")
	workspace._compare()
	workspace._compare()
	assert_int(workspace.changes_tree.get_root().get_child_count()).is_equal(1)
	assert_int(workspace._activity_rows.size()).is_equal(1)
	workspace.changes_tree.get_root().get_first_child().select(0)
	workspace._show_diff()
	assert_str(workspace._diff_before.text).is_equal("false")
	assert_str(workspace._diff_after.text).is_equal("true")

func test_system_metrics_sort_numerically_and_preserve_full_statistics() -> void:
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(_model())
	add_child(workspace)
	workspace._systems({1: {"active": true, "last_run_data": {"system_name": "Slow", "execution_time_ms": 10.0, "min_ms": 2.0, "max_ms": 12.0, "avg_ms": 5.0}}, 2: {"active": true, "last_run_data": {"system_name": "Fast", "execution_time_ms": 2.0, "max_ms": 3.0}}})
	var row: TreeItem = workspace.systems_tree.get_root().get_first_child()
	assert_str(row.get_text(0)).is_equal("Slow")
	assert_float(row.get_text(3).to_float()).is_equal(2.0)
	assert_float(row.get_text(4).to_float()).is_equal(12.0)
	assert_float(row.get_text(5).to_float()).is_equal(5.0)
	assert_str(workspace._system_summary.text).contains("Fastest: Fast")
	workspace.systems_tree.column_title_clicked.emit(2, MOUSE_BUTTON_LEFT)
	workspace.systems_tree.column_title_clicked.emit(2, MOUSE_BUTTON_LEFT)
	assert_str(workspace.systems_tree.get_root().get_first_child().get_text(0)).is_equal("Fast")


func test_relationship_rows_survive_refresh_and_activate_current_target() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	var target := {"world": 10, "epoch": 1, "id": 2, "iid": 101}
	view.snapshot = {"relationships": [{"iid": 300, "relation": "Owns", "label": "Target", "target": target}]}
	view._render()
	var row: TreeItem = view.relationship_tree.get_root().get_first_child()
	row.select(1)
	var opened: Array = []
	view.open_entity.connect(func(identity): opened.append(identity))
	for i in 5: view._render()
	assert_object(view.relationship_tree.get_selected()).is_same(row)
	assert_array(opened).is_empty()
	view.relationship_tree.item_activated.emit()
	assert_array(opened).contains_exactly([target])
	view.snapshot.relationships.clear()
	view._render()
	view.relationship_tree.item_activated.emit()
	assert_int(opened.size()).is_equal(1)

func test_incoming_relationship_opens_source_and_cannot_stage_removal_on_target() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	var source := {"world": 10, "epoch": 1, "id": 2, "iid": 101}
	view.snapshot = {"name": "Hero", "relationships": [], "incoming_relationships": [{"iid": 300, "relation": "OwnedBy", "source_label": "Coin", "source": source}]}
	view._render()
	assert_str(view._relationship_count.text).is_equal("0 outgoing · 1 incoming")
	var row: TreeItem = view.relationship_tree.get_root().get_first_child()
	assert_str(row.get_text(0)).contains("Incoming")
	assert_str(row.get_text(2)).is_equal("Coin")
	row.select(2)
	var opened: Array = []
	view.open_entity.connect(func(identity): opened.append(identity))
	for i in 5: view._render()
	assert_object(view.relationship_tree.get_selected()).is_same(row)
	assert_array(opened).is_empty()
	assert_bool(view._relationship_context().has("Stage removal")).is_false()
	view.relationship_tree.item_activated.emit()
	assert_array(opened).contains_exactly([source])
	assert_array(view.drafts).is_empty()
	view.snapshot.incoming_relationships.clear()
	view._render()
	assert_bool(view._relationships_empty.visible).is_true()
	view.relationship_tree.item_activated.emit()
	assert_int(opened.size()).is_equal(1)

func test_self_relationship_keeps_both_directions_distinct() -> void:
	var model := _model()
	var ref := {"world": 10, "epoch": 1, "id": 1, "iid": 100}
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, ref)
	add_child(view)
	view.snapshot = {"name": "Self", "relationships": [{"iid": 300, "relation": "Link", "label": "Self", "target": ref}], "incoming_relationships": [{"iid": 300, "relation": "Link", "source_label": "Self", "source": ref}]}
	view._render()
	var outgoing: TreeItem = view.relationship_tree.get_root().get_first_child()
	var incoming := outgoing.get_next()
	assert_str(outgoing.get_text(0)).contains("Outgoing")
	assert_str(incoming.get_text(0)).contains("Incoming")
	outgoing.select(0)
	assert_bool(view._relationship_context().has("Stage removal")).is_true()
	view._render()
	assert_object(outgoing.get_next()).is_same(incoming)

func test_graph_selection_does_not_navigate_but_double_click_does() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	var opened: Array = []
	view.open_entity.connect(func(identity): opened.append(identity))
	var payload := {"watched": [100], "nodes": [{"key": "e:101", "kind": "entity", "instance_id": 101, "id": 2, "name": "Target"}], "edges": []}
	view.graph_panel.apply_graph(1, payload)
	var node: GraphNode = view.graph_panel._nodes["e:101"]
	view.graph_panel.graph.node_selected.emit(node)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	node.gui_input.emit(click)
	assert_array(opened).is_empty()
	view.graph_panel.apply_graph(2, payload)
	click.double_click = true
	node.gui_input.emit(click)
	assert_int(opened.size()).is_equal(1)
	assert_int(opened[0].iid).is_equal(101)
	model.epoch = 2
	node.gui_input.emit(click)
	assert_int(opened.size()).is_equal(1)

func test_graph_resize_and_popout_preserve_graph_and_subscription() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	view.graph_toggle.button_pressed = true
	var users := model.watch_users.duplicate()
	var ids := model.graph_ids.duplicate()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	view._graph_resize_handle.gui_input.emit(click)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(0, 150)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	view._graph_resize_handle.gui_input.emit(drag)
	assert_float(view._graph_height).is_equal(510.0)
	assert_float(view.layout_definition().graph_height).is_equal(510.0)
	var panel: GECSEditorGraphPanel = view.graph_panel
	view._open_graph_window()
	assert_bool(view._graph_window.force_native).is_true()
	assert_bool(view._graph_window.unresizable).is_false()
	assert_object(view._graph_card.get_parent()).is_same(view._graph_window)
	view._graph_window.size = Vector2i(1200, 800)
	view._graph_window.close_requested.emit()
	assert_object(view._graph_card.get_parent()).is_same(view._sidebar)
	assert_object(view.graph_panel).is_same(panel)
	assert_dict(model.watch_users).is_equal(users)
	assert_dict(model.graph_ids).is_equal(ids)
	assert_float(view.graph_panel.custom_minimum_size.y).is_equal(510.0)
	view._open_graph_window()
	view.graph_toggle.button_pressed = false
	assert_object(view._graph_window).is_null()
	assert_bool(view._graph_card.visible).is_false()


func test_hello_restores_transport_after_world_change_and_pause_sends_command() -> void:
	var model := _model()
	var sent: Array = []
	model.sender = func(message, args): sent.append([message, args]); return true
	var workspace = auto_free(GECSExplorerWorkspace.new())
	workspace.configure(model)
	add_child(workspace)
	assert_bool(workspace.transport.pause_btn.disabled).is_true()
	var request := model.request("hello")
	model.accept({"request_id": request, "world": 10, "epoch": 1, "result": {"step_state": {"paused": false}, "catalogue": []}})
	assert_bool(workspace.transport.pause_btn.disabled).is_false()
	assert_bool(workspace.transport.step_btn.disabled).is_false()
	workspace.transport.pause_btn.pressed.emit()
	assert_array(sent.back()).is_equal(["gecs:step_pause", []])
	model.step_state = {"paused": true}
	model.updated.emit("step", model.step_state)
	assert_bool(workspace.transport.resume_btn.disabled).is_false()
	model.script_breaked = true
	model.updated.emit("step", model.step_state)
	assert_bool(workspace.transport.resume_btn.disabled).is_true()
	assert_bool(workspace.transport.step_btn.disabled).is_true()
	model.script_breaked = false
	model.updated.emit("step", model.step_state)
	assert_bool(workspace.transport.resume_btn.disabled).is_false()
	request = model.request("hello")
	model.accept({"request_id": request, "world": 20, "epoch": 1, "result": {"step_state": {"paused": false}, "catalogue": []}})
	assert_bool(workspace.transport.pause_btn.visible).is_true()
	assert_bool(workspace.transport.pause_btn.disabled).is_false()
	model.disconnect_session()
	assert_bool(workspace.transport.pause_btn.disabled).is_true()

func test_relationship_table_split_is_independent_and_survives_refresh_and_layout() -> void:
	var model := _model()
	model.world_id = 10
	model.epoch = 1
	var view = auto_free(GECSExplorerEntityView.new())
	view.configure(model, {"world": 10, "epoch": 1, "id": 1, "iid": 100})
	add_child(view)
	view.snapshot = {"name": "Subject", "relationships": []}
	assert_int(view._data_split.get_child_count()).is_equal(2)
	assert_int(view._data_split.dragger_visibility).is_equal(SplitContainer.DRAGGER_VISIBLE)
	view._data_split.split_offset = -120
	view._render()
	assert_int(view._data_split.split_offset).is_equal(-120)
	var layout: Dictionary = view.layout_definition()
	view._data_split.split_offset = 0
	view.pending_layout = layout
	view._restore_layout()
	assert_int(view._data_split.split_offset).is_equal(-120)
	assert_bool(view._save_button.get_parent().visible).is_false()
