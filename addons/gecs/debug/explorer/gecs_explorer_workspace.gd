@tool
class_name GECSExplorerWorkspace
extends VBoxContainer
## Main-screen investigation workspace. All detached views use the same model.
const UI = preload("res://addons/gecs/debug/explorer/gecs_explorer_ui.gd")
const Codec = preload("res://addons/gecs/debug/explorer/gecs_explorer_codec.gd")
const PREFS := "res://.godot/editor/gecs_explorer.json"

var model: GECSExplorerModel
var transport: GECSEditorStepPanel
var nav: TabContainer
var entity_tabs: TabContainer
var browser: Tree
var entity_filter: LineEdit
var query_editor: CodeEdit
var query_results: Tree
var query_filter: LineEdit
var query_status: Label
var columns_edit: LineEdit
var snippet: CodeEdit
var output: RichTextLabel
var changes_tree: Tree
var systems_tree: Tree
var watch_tree: Tree
var session_label: Label
var status: Label
var named_query: LineEdit
var saved_picker: OptionButton
var component_picker: OptionButton
var property_name: LineEdit
var property_value: LineEdit
var property_op: OptionButton
var condition_popup: PopupPanel
var condition_source: OptionButton
var condition_op: OptionButton
var condition_value: LineEdit
var step_limit: SpinBox
var views: Array = []
var detached: Array = []
var history: Array = []
var history_index := -1
var query_history: Array = []
var query_history_picker: OptionButton
var spec: Dictionary = {"all": [], "any": [], "none": [], "properties": [], "groups": [], "relationships": []}
var saved: Dictionary = {"queries": {}, "snippets": {}, "watches": []}
var _page := 0
var _sort := "name"
var _descending := false
var _generated := ""
var _last_sample_pull := 0
var _last_browser_pull := 0
var _query_watch_sequence := 0
var _browser_page := 0
var _browser_status: Label
var _query_rows: Array = []
var _unresolved: Array = []
var _file_dialog: FileDialog
var _cancel_run: Button
var _query_builder_popup: PopupPanel
var _query_library_popup: PopupPanel
var _builder_error: Label
var _systems_data: Dictionary = {}
var _system_items: Dictionary = {}
var _run_status: Dictionary = {}
var _system_sort := 4
var _system_descending := true
var _system_summary: Label
var _watch_detail: Tree
var _watch_help: Label
var _latest_watches: Dictionary = {}
var _capture_before: OptionButton
var _capture_after: OptionButton
var _diff_before: TextEdit
var _diff_after: TextEdit
var _diff_title: Label
var _change_mode: OptionButton
var _comparison_rows: Array = []
var _activity_rows: Array = []
var _builder_terms: VBoxContainer
var _builder_group: OptionButton
const Overview = preload("res://addons/gecs/debug/explorer/gecs_explorer_overview.gd")
var overview: Control
var _overview_pending := 0
var _overview_manual_pending := false
var _overview_last_pull := 0
var _connection_badge: PanelContainer
var _world_caption: Label
var _activity_row: HBoxContainer
var _last_status := ""
var _status_history: Array[String] = []
var _status_popup: PopupPanel
var _status_details: RichTextLabel
var _snapshot_file: FileDialog
var _snapshot_data: Dictionary = {}
var _restore_dialog: ConfirmationDialog
var _restore_details: RichTextLabel
var _restore_token := -1
var _snapshot_menu: MenuButton

func configure(session: GECSExplorerModel) -> void:
	model = session
	model.poll_provider = _poll_requests
	model.updated.connect(_updated)
	model.request_finished.connect(_finished)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", UI.px(8))
	var connection := HBoxContainer.new()
	add_child(connection)
	_world_caption = UI.label(connection, "WORLD", 11, UI.ACCENT)
	session_label = UI.label(connection, "Start a scene to connect", 13, UI.MUTED)
	session_label.clip_text = true
	session_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	session_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.menu(connection, "Workspace ▾", ["Export setup…", "Import setup…", "Save pinned setup", "Reconnect saved watches"], [func(): _choose_file(false), func(): _choose_file(true), _save_pins, _restore_pins])
	var execution := VBoxContainer.new()
	add_child(execution)
	transport = GECSEditorStepPanel.new()
	execution.add_child(transport)
	transport.tabs.hide()
	# The shared panel's spacer competes with the world path for width here.
	# The connection group itself fills all remaining toolbar space.
	for child in transport.transport.get_children():
		if child.get_class() == "Control": child.hide()
	connection.reparent(transport.transport)
	connection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connection_badge = PanelContainer.new()
	connection.add_child(_connection_badge)
	transport.status_label.reparent(_connection_badge)
	transport.status_label.clip_text = false
	transport.status_label.custom_minimum_size.x = UI.px(110)
	transport.state_applied.connect(func(_state: Dictionary): _update_connection_badge())
	transport.status_label.add_theme_color_override("font_color", UI.ACCENT)
	transport.status_label.add_theme_font_size_override("font_size", UI.px(13))
	transport.pause_btn.text = "Pause ECS"
	transport.resume_btn.text = "Resume ECS"
	transport.step_btn.theme_type_variation = "ExplorerPrimary"
	transport.send = func(message: String, args: Array):
		if model != null and model.connected and model.world_id != 0 and not model.script_breaked and model.sender.is_valid(): return model.sender.call(message, args)
		return false
	transport.selected_entities_provider = func():
		var view := active_view()
		return [view.ref.iid] if view != null else []
	transport.step_kind.item_selected.connect(func(index: int): model.step_state["preferred_kind"] = index)
	_button(transport.transport, "Run Until…", func(): condition_popup.popup_centered())
	_cancel_run = _button(transport.transport, "Cancel run", func(): model.request("cancel_run"))
	_cancel_run.hide()
	_snapshot_menu = UI.menu(transport.transport, "State ▾", ["Export ECS snapshot…", "Restore component values…"], [
		func():
			if _require_snapshot_session():
				status.text = "Capturing ECS snapshot…"
				model.request("snapshot_export"),
		func():
			if _require_snapshot_session():
				_snapshot_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
				_snapshot_file.title = "Preview an ECS snapshot"
				_snapshot_file.popup_centered_ratio(0.65)
	])
	_snapshot_menu.tooltip_text = "ECS inspection snapshots; value restore does not recreate entities or restore physics, timers, or non-ECS state."
	_activity_row = HBoxContainer.new()
	execution.add_child(_activity_row)
	status = UI.label(_activity_row, "Start a scene to connect. Retained data stays available for inspection.", 12, UI.MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(_activity_row, "Activity ▾", func():
		_status_details.text = "\n\n".join(_status_history)
		_status_popup.popup_centered(Vector2i(UI.px(600), UI.px(280)))
	)
	_status_popup = PopupPanel.new()
	add_child(_status_popup)
	_status_details = RichTextLabel.new()
	_status_details.selection_enabled = true
	_status_details.custom_minimum_size = Vector2(UI.px(350), UI.px(180))
	_status_popup.add_child(_status_details)
	status.clip_text = true
	nav = TabContainer.new()
	nav.use_hidden_tabs_for_min_size = false
	nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(nav)
	_build_explore()
	_build_queries()
	_build_watches()
	_build_systems()
	_build_changes()
	_build_conditions()
	_snapshot_file = FileDialog.new()
	_snapshot_file.access = FileDialog.ACCESS_FILESYSTEM
	_snapshot_file.add_filter("*.gecs-state.json", "GECS ECS snapshot")
	_snapshot_file.file_selected.connect(_snapshot_file_selected)
	add_child(_snapshot_file)
	_restore_dialog = ConfirmationDialog.new()
	_restore_dialog.title = "Restore component values"
	_restore_dialog.ok_button_text = "Restore values"
	_restore_dialog.confirmed.connect(func():
		if not _require_snapshot_session() or not _require_clean_drafts(): return
		status.text = "Restoring ECS component values…"
		model.request("snapshot_restore", {"token": _restore_token})
	)
	add_child(_restore_dialog)
	_restore_details = RichTextLabel.new()
	_restore_details.custom_minimum_size = Vector2(UI.px(540), UI.px(260))
	_restore_details.selection_enabled = true
	_restore_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_restore_dialog.add_child(_restore_details)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.json", "GECS workspace")
	_file_dialog.file_selected.connect(_file_selected)
	add_child(_file_dialog)
	if FileAccess.file_exists(PREFS):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS))
		if loaded is Dictionary: _load_setup(loaded)
	if model != null:
		_refresh_transport()
		if model.connected: model.request("hello")
	resized.connect(_fit_header)
	_fit_header.call_deferred()

func _box(name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = name
	nav.add_child(box)
	return box

func _button(parent: Node, text: String, callback: Callable) -> Button:
	return UI.button(parent, text, callback)

func _line(parent: Node, hint: String, width := 140) -> LineEdit:
	var line := LineEdit.new()
	line.placeholder_text = hint
	line.custom_minimum_size.x = UI.px(width)
	parent.add_child(line)
	return line

func _tree(parent: Node, titles: Array) -> Tree:
	var tree := Tree.new()
	tree.select_mode = Tree.SELECT_ROW
	tree.columns = titles.size()
	tree.hide_root = true
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in titles.size():
		tree.set_column_title(i, titles[i])
		tree.set_column_clip_content(i, true)
	tree.create_item()
	parent.add_child(tree)
	return tree

func _build_explore() -> void:
	var box := _box("Explore")
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	var browse := UI.card(split, "Entities", "Find an entity to begin investigating.", true)
	browse.get_parent().custom_minimum_size.x = UI.px(260)
	browse.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var search := HBoxContainer.new()
	browse.add_child(search)
	entity_filter = _line(search, "Search entities…", 120)
	entity_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entity_filter.text_submitted.connect(func(_text: String):
		_browser_page = 0
		_refresh_browser()
	)
	UI.button(search, "↻", func():
		_browser_page = 0
		_refresh_browser()
	, false, "Refresh entities using the current search")
	browser = _tree(browse, ["Entity", "State"])
	browser.set_column_expand(1, false)
	browser.set_column_custom_minimum_width(1, UI.px(52))
	browser.item_activated.connect(func():
		var row := browser.get_selected()
		if row: open_entity(row.get_metadata(0))
	)
	_browser_status = UI.label(browse, "Waiting for the world", 12, UI.MUTED)
	var paging := HBoxContainer.new()
	browse.add_child(paging)
	UI.button(paging, "‹", func():
		_browser_page = maxi(0, _browser_page - 1)
		_refresh_browser()
	, false, "Previous page")
	UI.button(paging, "›", func():
		_browser_page += 1
		_refresh_browser()
	, false, "Next page")
	var open_button := UI.button(paging, "Open", func():
		if browser.get_selected(): open_entity(browser.get_selected().get_metadata(0))
	, true)
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entity_actions(paging, browser)
	UI.hint(browse, "Expand a row for components and relationships. Double-click to open.")
	var work := VBoxContainer.new()
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(work)
	entity_tabs = TabContainer.new()
	entity_tabs.use_hidden_tabs_for_min_size = false
	entity_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entity_tabs.drag_to_rearrange_enabled = true
	work.add_child(entity_tabs)
	var tab_bar := entity_tabs.get_tab_bar()
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	tab_bar.tab_close_pressed.connect(func(index: int):
		entity_tabs.current_tab = index
		_close_active()
	)
	tab_bar.tab_rmb_clicked.connect(func(index: int):
		entity_tabs.current_tab = index
		_tab_menu()
	)
	var bar: HBoxContainer = paging
	UI.button(bar, "←", func(): _navigate(-1), false, "Previous entity")
	UI.button(bar, "→", func(): _navigate(1), false, "Next entity")
	UI.button(transport.transport, "Capture", _capture, false, "Snapshot open entity tabs and watched queries for comparison")
	overview = Overview.new()
	overview.name = "World"
	entity_tabs.add_child(overview)
	overview.refresh_requested.connect(func(): _request_overview(true))
	overview.preferences_changed.connect(func():
		saved["overview"] = overview.preferences()
		_save_setup()
		_overview_last_pull = 0
	)
	overview.systems_requested.connect(func(): nav.current_tab = 3)
	overview.query_requested.connect(func(kind: String, path: String):
		spec = {"all": [path]} if kind == "component" else {"relationships": [{"component": path}]}
		_page = 0
		query_filter.clear()
		_generate_query()
		nav.current_tab = 1
		_run_query()
	)
	entity_tabs.tab_changed.connect(func(_index: int):
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER if entity_tabs.get_current_tab_control() == overview else TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
		_overview_last_pull = 0
	)
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER

func _build_queries() -> void:
	var box := _box("Queries")
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.use_hidden_tabs_for_min_size = false
	box.add_child(tabs)
	var work := VBoxContainer.new()
	work.name = "Query workbench"
	tabs.add_child(work)
	var editor_card := UI.card(work)
	var heading := UI.heading(editor_card, "Find exactly what you need", "Write a QueryBuilder expression, or use the guided builder.")
	UI.button(heading, "Build query…", func(): _open_builder())
	UI.button(heading, "Saved queries…", func(): _query_library_popup.popup_centered(Vector2i(UI.px(440), 0)))
	query_editor = CodeEdit.new()
	query_editor.custom_minimum_size.y = UI.px(70)
	query_editor.text = "ECS.world.query"
	query_editor.code_completion_enabled = true
	query_editor.gutters_draw_line_numbers = true
	var syntax := CodeHighlighter.new()
	for word in ["q", "world", "ECS"]: syntax.add_keyword_color(word, UI.ACCENT)
	syntax.number_color = UI.WARNING
	syntax.member_variable_color = UI.TEXT
	syntax.function_color = UI.ACCENT
	syntax.symbol_color = UI.MUTED
	query_editor.syntax_highlighter = syntax
	query_editor.code_completion_requested.connect(func():
		for entry in model.catalogue: query_editor.add_code_completion_option(CodeEdit.KIND_CLASS, entry.name, entry.name)
		query_editor.update_code_completion_options(true)
	)
	editor_card.add_child(query_editor)
	var run_bar := HFlowContainer.new()
	editor_card.add_child(run_bar)
	UI.button(run_bar, "Run query", func():
		_page = 0
		_run_query()
	, true)
	UI.button(run_bar, "Watch query", _watch_query, false, "Live query watches require a query created with the guided builder.")
	UI.button(run_bar, "Try a project example", func():
		if not model.catalogue.is_empty():
			var project_components := model.catalogue.filter(func(entry): return not str(entry.path).begins_with("res://addons/"))
			spec = {"all": [(project_components[0] if not project_components.is_empty() else model.catalogue[0]).path]}
			_generate_query()
	)
	var results := UI.card(work, "Results", "Double-click a row to open its entity. Click a column header to sort.", true)
	var result_tools := HFlowContainer.new()
	results.add_child(result_tools)
	query_filter = _line(result_tools, "Filter entity names…", 180)
	query_filter.text_submitted.connect(func(_text: String):
		_page = 0
		_run_query(false)
	)
	var column_toggle := UI.button(result_tools, "Columns…", func(): columns_edit.get_parent().visible = not columns_edit.get_parent().visible)
	column_toggle.tooltip_text = "Choose component properties to include in the results table."
	UI.button(result_tools, "Open page in tabs", func():
		for entity in _query_rows:
			open_entity(entity.identity)
			active_view().pinned = true
	)
	columns_edit = LineEdit.new()
	columns_edit.placeholder_text = "C_Health:current, C_Player:display_name"
	UI.field(results, "Result columns · component:property, separated by commas", columns_edit, "Up to 16 columns. Run the query to update the table.")
	columns_edit.get_parent().hide()
	query_results = _tree(results, ["Entity"])
	query_results.item_activated.connect(func():
		if query_results.get_selected(): open_entity(query_results.get_selected().get_metadata(0))
	)
	query_results.column_title_clicked.connect(func(index: int, _button: int):
		var columns := _columns()
		if index in [1, 2]: return
		_sort = "name" if index == 0 else columns[index - 3]
		_descending = not _descending
		_run_query(false)
	)
	var paging := HBoxContainer.new()
	results.add_child(paging)
	query_status = UI.label(paging, "No results yet · Run a query above", 12, UI.MUTED)
	query_status.clip_text = true
	query_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(paging, "‹", func():
		_page = maxi(0, _page - 1)
		_run_query(false)
	, false, "Previous page")
	UI.button(paging, "›", func():
		_page += 1
		_run_query(false)
	, false, "Next page")
	_entity_actions(paging, query_results)
	_build_query_builder()
	_build_query_library()
	_build_scratchpad(tabs)

func _build_query_library() -> void:
	_query_library_popup = PopupPanel.new()
	add_child(_query_library_popup)
	var body := VBoxContainer.new()
	_query_library_popup.add_child(body)
	UI.heading(body, "Query library", "Save an investigation to use again. Loading never runs it.")
	saved_picker = OptionButton.new()
	saved_picker.fit_to_longest_item = false
	saved_picker.item_selected.connect(func(index: int):
		var name := saved_picker.get_item_text(index)
		var entry: Dictionary = saved.queries.get(name, {})
		named_query.text = name
		query_editor.text = entry.get("text", "q")
		spec = entry.get("spec", {}).duplicate(true)
		_generated = entry.get("generated", "")
		_query_library_popup.hide()
	)
	UI.field(body, "Saved queries", saved_picker)
	query_history_picker = OptionButton.new()
	query_history_picker.fit_to_longest_item = false
	query_history_picker.item_selected.connect(func(index: int):
		query_editor.text = query_history[index]
		_query_library_popup.hide()
	)
	UI.field(body, "Recent queries", query_history_picker)
	named_query = LineEdit.new()
	named_query.placeholder_text = "e.g. Players with low health"
	UI.field(body, "Save current query as", named_query)
	var actions := HFlowContainer.new()
	body.add_child(actions)
	UI.button(actions, "Save query", func():
		if named_query.text.is_empty(): return
		saved.queries[named_query.text] = {"text": query_editor.text, "spec": spec.duplicate(true), "generated": _generated}
		_save_setup()
		_saved_options()
		_query_library_popup.hide()
	, true)
	UI.button(actions, "Done", func(): _query_library_popup.hide())

func _open_builder() -> void:
	_refresh_builder_terms()
	var available := get_viewport_rect().size * 0.85
	_query_builder_popup.popup_centered(Vector2i(mini(UI.px(660), int(available.x)), mini(UI.px(520), int(available.y))))

func _build_query_builder() -> void:
	_query_builder_popup = PopupPanel.new()
	add_child(_query_builder_popup)
	var body := VBoxContainer.new()
	_query_builder_popup.add_child(body)
	UI.heading(body, "Filter entities", "All groups apply together. Add components, then refine their properties.")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = UI.px(100)
	body.add_child(scroll)
	_builder_terms = VBoxContainer.new()
	_builder_terms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_builder_terms)
	var add := HBoxContainer.new()
	body.add_child(add)
	_builder_group = OptionButton.new()
	for title in ["All", "Any", "None"]: _builder_group.add_item(title)
	add.add_child(_builder_group)
	component_picker = OptionButton.new()
	component_picker.fit_to_longest_item = false
	component_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.add_child(component_picker)
	UI.button(add, "+ Component", func(): _add_term(["all", "any", "none"][_builder_group.selected]))
	UI.button(add, "+ Relationship", func():
		var path := _picked_component()
		if path != "":
			spec.get_or_add("relationships", []).append({"component": path})
			_generate_query()
	)
	var properties := HBoxContainer.new()
	body.add_child(properties)
	property_name = LineEdit.new()
	property_name.placeholder_text = "Property name"
	property_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	properties.add_child(property_name)
	property_op = OptionButton.new()
	for op in ["=", "≠", ">", "≥", "<", "≤"]: property_op.add_item(op)
	properties.add_child(property_op)
	property_value = LineEdit.new()
	property_value.placeholder_text = 'Value: 20, true, "idle"'
	property_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	properties.add_child(property_value)
	_builder_error = UI.label(body, "", 12, UI.ERROR)
	_builder_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_builder_error.hide()
	UI.button(body, "Add property filter", func():
		_builder_error.hide()
		var parsed := _parse_value(property_value.text)
		if parsed.has("error") or property_name.text.strip_edges().is_empty() or _picked_component().is_empty():
			_builder_error.text = "Choose a component and property, and enter a value such as 20, true, or a quoted string."
			_builder_error.show()
			return
		if _builder_group.selected == 2:
			_builder_error.text = "None excludes component types. Property comparisons are supported in All and Any groups."
			_builder_error.show()
			return
		var group: String = ["all", "any"][_builder_group.selected]
		var operation: String = ["_eq", "_ne", "_gt", "_gte", "_lt", "_lte"][property_op.selected]
		var term := {"component": _picked_component(), "property": property_name.text.strip_edges(), "op": operation, "value": Codec.encode(parsed.value), "group": group}
		# Replace the same comparator; never generate duplicate dictionary keys.
		spec["properties"] = spec.get("properties", []).filter(func(p): return not (p.component == term.component and p.property == term.property and p.op == term.op and p.get("group", "all") == group))
		spec.properties.append(term)
		_add_term(group)
		_generate_query()
	)
	var other := HBoxContainer.new()
	body.add_child(other)
	var group := LineEdit.new()
	group.placeholder_text = "Godot node group"
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	other.add_child(group)
	UI.button(other, "+ Group", func():
		if not group.text.strip_edges().is_empty():
			spec.get_or_add("groups", []).append(group.text.strip_edges())
			_generate_query()
	)
	var enabled := OptionButton.new()
	for title in ["Any state", "Enabled", "Disabled"]: enabled.add_item(title)
	other.add_child(enabled)
	enabled.item_selected.connect(func(index: int):
		spec["enabled"] = ["any", "enabled", "disabled"][index]
		_generate_query()
	)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	UI.button(actions, "Reset", func():
		spec = {"all": [], "any": [], "none": [], "properties": [], "groups": [], "relationships": []}
		enabled.select(0)
		_generate_query()
	)
	UI.button(actions, "Use query", func(): _query_builder_popup.hide(), true)
	_refresh_builder_terms()

func _refresh_builder_terms() -> void:
	if _builder_terms == null: return
	for child in _builder_terms.get_children():
		_builder_terms.remove_child(child)
		child.queue_free()
	for group in ["all", "any", "none"]:
		var card := UI.card(_builder_terms)
		UI.label(card, {"all": "ALL · must match every component", "any": "ANY · must match at least one", "none": "NONE · exclude these component types"}[group], 12, UI.ACCENT)
		var paths: Array = spec.get(group, []).duplicate()
		for property in spec.get("properties", []):
			if property.get("group", "all") == group and not paths.has(property.component): paths.append(property.component)
		if paths.is_empty(): UI.label(card, "No filters in this group", 12, UI.MUTED)
		for path in paths:
			var row := HBoxContainer.new()
			card.add_child(row)
			var title := UI.button(row, _class_name_for(path), func():
				_builder_group.select(["all", "any", "none"].find(group))
				for i in component_picker.item_count:
					if component_picker.get_item_metadata(i) == path: component_picker.select(i)
			)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UI.button(row, "×", func():
				spec.get_or_add(group, []).erase(path)
				spec["properties"] = spec.get("properties", []).filter(func(p): return p.component != path or p.get("group", "all") != group)
				_generate_query()
			)
			for property in spec.get("properties", []):
				if property.component != path or property.get("group", "all") != group: continue
				var filter_row := HBoxContainer.new()
				card.add_child(filter_row)
				var label := UI.label(filter_row, "    " + property.property + " " + property.op.trim_prefix("_") + " " + property.value.display, 12, UI.MUTED)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				UI.button(filter_row, "×", func():
					spec.properties.erase(property)
					_generate_query()
				)
	for key in ["relationships", "groups"]:
		for term in spec.get(key, []):
			var row := HBoxContainer.new()
			_builder_terms.add_child(row)
			var title := UI.label(row, "Relationship: " + _class_name_for(term.component) if key == "relationships" else "Node group: " + str(term), 12, UI.MUTED)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UI.button(row, "×", func():
				spec[key].erase(term)
				_generate_query()
			)

func _build_scratchpad(parent: TabContainer) -> void:
	var box := VBoxContainer.new()
	box.name = "Scratchpad"
	parent.add_child(box)
	var code := UI.card(box, "Runtime scratchpad", "Run GDScript in the game with access to world, q, ECS, entity, and selection.", true)
	snippet = CodeEdit.new()
	snippet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	snippet.custom_minimum_size.y = UI.px(100)
	snippet.gutters_draw_line_numbers = true
	snippet.syntax_highlighter = query_editor.syntax_highlighter.duplicate()
	snippet.code_completion_enabled = true
	snippet.code_completion_requested.connect(func():
		for entry in model.catalogue: snippet.add_code_completion_option(CodeEdit.KIND_CLASS, entry.name, entry.name)
		for binding in ["entity", "selection", "world", "q", "ECS"]: snippet.add_code_completion_option(CodeEdit.KIND_VARIABLE, binding, binding)
		snippet.update_code_completion_options(true)
	)
	snippet.text = "# Return a value to inspect it below.\nreturn world.query.execute().size()"
	code.add_child(snippet)
	var bar := HFlowContainer.new()
	code.add_child(bar)
	UI.button(bar, "Run once", func():
		var view := active_view()
		var ref: Dictionary = view.ref if view != null else {}
		output.text = "Running…"
		model.request("scratchpad", {"source": snippet.text, "entity": ref, "selection": [ref] if not ref.is_empty() else []})
	, true)
	var library := PopupPanel.new()
	add_child(library)
	var form := VBoxContainer.new()
	library.add_child(form)
	UI.heading(form, "Saved snippets", "Loading a snippet never executes it.")
	var name_edit := LineEdit.new()
	name_edit.custom_minimum_size.x = UI.px(300)
	name_edit.placeholder_text = "Snippet name"
	var saved_snippets := OptionButton.new()
	saved_snippets.fit_to_longest_item = false
	UI.field(form, "Saved snippets", saved_snippets)
	library.about_to_popup.connect(func():
		saved_snippets.clear()
		for title in saved.snippets: saved_snippets.add_item(title)
	)
	saved_snippets.item_selected.connect(func(index: int): name_edit.text = saved_snippets.get_item_text(index))
	UI.field(form, "Name", name_edit)
	UI.button(form, "Save current snippet", func():
		if not name_edit.text.is_empty():
			saved.snippets[name_edit.text] = snippet.text
			_save_setup()
			library.hide()
	)
	UI.button(form, "Load snippet", func():
		snippet.text = saved.snippets.get(name_edit.text, snippet.text)
		library.hide()
	)
	UI.button(bar, "Saved snippets…", func(): library.popup_centered())
	UI.hint(code, "Runs only when requested. Runtime errors appear in Godot's debugger; running GDScript cannot be safely interrupted here.")
	var returned := UI.card(box, "Returned value", "The result of the last explicit execution.", true)
	returned.get_parent().size_flags_stretch_ratio = 0.5
	output = RichTextLabel.new()
	output.text = "Nothing has run yet."
	output.custom_minimum_size.y = UI.px(70)
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	returned.add_child(output)

func _build_watches() -> void:
	var page := _box("Watches")
	var box := UI.card(page, "Live watches", "Open entity tabs share one subscription each. Guided query watches track membership. Select a watch to inspect its live data.", true)
	var bar := HFlowContainer.new()
	box.add_child(bar)
	_button(bar, "Find an entity", func(): nav.current_tab = 0)
	_button(bar, "Create query watch", func(): nav.current_tab = 1)
	_button(bar, "Capture", _capture)
	_button(bar, "Reconnect saved", _restore_pins)
	_button(bar, "Remove selected", _remove_watch)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	watch_tree = _tree(split, ["Watch", "Status", "Samples / matches"])
	watch_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail)
	_watch_help = UI.hint(detail, "Select a watch on the left. Entity watches show values; query watches show matching entities.")
	_watch_detail = _tree(detail, ["Component / property or entity", "Live value / components"])
	watch_tree.item_selected.connect(_show_watch)
	watch_tree.item_activated.connect(_open_watch)
	_watch_detail.item_activated.connect(func():
		var row := _watch_detail.get_selected()
		if row and row.get_metadata(0) is Dictionary:
			var info: Dictionary = row.get_metadata(0)
			open_entity(info.get("entity", {}))
			if active_view() and info.has("property_path"):
				active_view().pending_property_path = info.property_path
				active_view()._focus_pending_property()
	)
	UI.context_menu(_watch_detail, func(): return {"Open entity / property": func(): _watch_detail.item_activated.emit(), "Copy live value": func():
		var row := _watch_detail.get_selected()
		if row: DisplayServer.clipboard_set(row.get_text(1))
	})
	UI.context_menu(watch_tree, func(): return {"Open watch": _open_watch, "Remove watch / close tab": _remove_watch, "Save setup": _save_pins})

func _open_watch() -> void:
	var row := watch_tree.get_selected()
	if row and row.get_metadata(0) is Dictionary and row.get_metadata(0).has("entity"): open_entity(row.get_metadata(0).entity)

func _remove_watch() -> void:
	var row := watch_tree.get_selected()
	if row == null: return
	var key := str(row.get_meta("key", ""))
	for view in views:
		if view._watch_key != key: continue
		if not view.drafts.is_empty():
			status.text = "Apply or discard this entity's drafts before closing its watch."
			return
		if view.get_parent() != entity_tabs:
			status.text = "Dock the detached entity tab before removing its watch."
			return
		entity_tabs.current_tab = view.get_index()
		_close_active()
		_refresh_watches()
		return
	if not key.is_empty(): model.unwatch(key)
	_refresh_watches()

func _show_watch() -> void:
	var selected_path: Variant = _watch_detail.get_selected().get_metadata(0) if _watch_detail.get_selected() else null
	var scroll := _watch_detail.get_scroll().y
	_watch_detail.clear()
	var root := _watch_detail.create_item()
	var row := watch_tree.get_selected()
	if row == null or not row.get_metadata(0) is Dictionary: return
	var definition: Dictionary = row.get_metadata(0)
	var key := str(row.get_meta("key", ""))
	if definition.has("spec"):
		var last: Dictionary = _latest_watches.get(key, {})
		_watch_help.text = "%d matching entities · showing the first 100. Double-click to open." % last.get("total", 0)
		for entity in last.get("rows", []):
			var item := _watch_detail.create_item(root)
			item.set_text(0, entity.name)
			item.set_text(1, ", ".join(entity.get("component_names", [])))
			item.set_metadata(0, {"entity": entity.identity})
	else:
		var snapshot: Dictionary = model.snapshots.get(int(definition.get("entity", {}).get("iid", 0)), {})
		_watch_help.text = "Live values · double-click a property to edit or add a chart in its entity tab."
		for component in snapshot.get("components", []):
			for field in component.fields:
				if not field.get("exported", false): continue
				var item := _watch_detail.create_item(root)
				item.set_text(0, component.name + " / " + field.name)
				item.set_text(1, field.value.display)
				item.set_metadata(0, {"entity": definition.entity, "property_path": component.script + ":" + field.name})
		for relation in snapshot.get("relationships", []):
			var item := _watch_detail.create_item(root)
			item.set_text(0, relation.relation + " →")
			item.set_text(1, relation.label)
			item.set_metadata(0, {"entity": relation.target})
	for item in root.get_children():
		if selected_path != null and item.get_metadata(0) == selected_path: item.select(0)
	for child in _watch_detail.get_children(true):
		if child is VScrollBar: child.set_deferred("value", scroll)

func _build_systems() -> void:
	var page := _box("Systems")
	var box := UI.card(page, "System performance", "Timings in milliseconds. Click a heading to sort; right-click a system for actions.", true)
	_system_summary = UI.label(box, "Waiting for system metrics…", 13, UI.ACCENT)
	var bar := HFlowContainer.new()
	box.add_child(bar)
	_button(bar, "Open script", func(): _system_action("script"))
	_button(bar, "Enable / disable", func(): _system_action("toggle"))
	_button(bar, "Break before", func(): _system_action("break"))
	_button(bar, "Reset timings", func(): model.sender.call("gecs:reset_system_metrics", []))
	systems_tree = _tree(box, ["System", "Group", "Last ms", "Min ms", "Max ms", "Avg ms", "Entities", "Archetypes", "Order", "State"])
	systems_tree.set_column_expand_ratio(0, 3)
	systems_tree.column_title_clicked.connect(func(index: int, button: int):
		if button != MOUSE_BUTTON_LEFT: return
		_system_descending = not _system_descending if _system_sort == index else index >= 2
		_system_sort = index
		_systems(_systems_data)
	)
	systems_tree.item_activated.connect(func(): _system_action("script"))
	UI.context_menu(systems_tree, func(): return {
		"Open system script": func(): _system_action("script"),
		"Enable / disable system": func(): _system_action("toggle"),
		"Break before system": func(): _system_action("break")
	})

func _system_action(action: String) -> void:
	var row := systems_tree.get_selected()
	if row == null: return
	var data: Dictionary = row.get_metadata(0)
	match action:
		"script":
			if Engine.is_editor_hint() and not str(data.script).is_empty(): EditorInterface.edit_script(load(data.script))
		"toggle": model.sender.call("gecs:set_system_active", [data.id, not data.get("active", true)])
		"break": model.sender.call("gecs:breakpoint_add", [{"kind": "system", "system_id": data.id}])

func _build_changes() -> void:
	var page := _box("Changes")
	var box := UI.card(page, "Changes", "Capture before and after a step. Select a changed field to see its complete values side by side.", true)
	var bar := HFlowContainer.new()
	box.add_child(bar)
	_change_mode = OptionButton.new()
	_change_mode.add_item("Capture comparison")
	_change_mode.add_item("Live activity")
	bar.add_child(_change_mode)
	_change_mode.item_selected.connect(func(_index: int): _render_changes())
	_button(bar, "Capture now", _capture)
	_capture_before = OptionButton.new()
	_capture_after = OptionButton.new()
	for picker in [_capture_before, _capture_after]:
		picker.fit_to_longest_item = false
		picker.custom_minimum_size.x = UI.px(160)
	UI.label(bar, "Before", 12, UI.MUTED)
	bar.add_child(_capture_before)
	UI.label(bar, "After", 12, UI.MUTED)
	bar.add_child(_capture_after)
	_button(bar, "Compare", _compare).theme_type_variation = "ExplorerPrimary"
	_button(bar, "Open property", _focus_change)
	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	changes_tree = _tree(split, ["Source", "Entity / field", "− Before", "+ After"])
	changes_tree.custom_minimum_size.y = UI.px(110)
	changes_tree.item_activated.connect(_focus_change)
	changes_tree.item_selected.connect(_show_diff)
	UI.context_menu(changes_tree, func(): return {"Open property": _focus_change, "Copy before": func(): DisplayServer.clipboard_set(_diff_before.text), "Copy after": func(): DisplayServer.clipboard_set(_diff_after.text)})
	var detail := VBoxContainer.new()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(detail)
	_diff_title = UI.label(detail, "Capture twice, then Compare to see what changed.", 13, UI.MUTED)
	_diff_title.clip_text = true
	var sides := HSplitContainer.new()
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(sides)
	for side in [0, 1]:
		var pane := VBoxContainer.new()
		pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sides.add_child(pane)
		UI.label(pane, "− BEFORE" if side == 0 else "+ AFTER", 12, UI.ERROR if side == 0 else UI.ACCENT)
		var text := TextEdit.new()
		text.editable = false
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.y = UI.px(100)
		text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		pane.add_child(text)
		if side == 0: _diff_before = text
		else: _diff_after = text

func _capture_options() -> void:
	_capture_before.clear()
	_capture_after.clear()
	for i in model.captures.size():
		var capture: Dictionary = model.captures[i]
		var title := "Capture %d · step %s" % [i + 1, capture.get("step", "—")]
		_capture_before.add_item(title)
		_capture_after.add_item(title)
	if model.captures.size() > 1: _capture_before.select(model.captures.size() - 2)
	if not model.captures.is_empty(): _capture_after.select(model.captures.size() - 1)

func _render_changes() -> void:
	changes_tree.clear()
	changes_tree.create_item()
	var rows := _comparison_rows if _change_mode.selected == 0 else _activity_rows
	for entry in rows: _draw_change_row(entry)
	_diff_before.text = ""
	_diff_after.text = ""
	_diff_title.text = "%d changed fields · select a row to inspect its values" % rows.size()

func _show_diff() -> void:
	var row := changes_tree.get_selected()
	if row == null: return
	_diff_title.text = row.get_text(1)
	_diff_before.text = row.get_text(2)
	_diff_after.text = row.get_text(3)
	# Per-line emphasis makes large arrays and dictionaries easier to compare.
	for i in _diff_before.get_line_count():
		_diff_before.set_line_background_color(i, Color.TRANSPARENT)
		if i >= _diff_after.get_line_count() or _diff_before.get_line(i) != _diff_after.get_line(i): _diff_before.set_line_background_color(i, Color(UI.ERROR, 0.12))
	for i in _diff_after.get_line_count():
		_diff_after.set_line_background_color(i, Color.TRANSPARENT)
		if i >= _diff_before.get_line_count() or _diff_after.get_line(i) != _diff_before.get_line(i): _diff_after.set_line_background_color(i, Color(UI.ACCENT, 0.12))

func _build_conditions() -> void:
	condition_popup = PopupPanel.new()
	add_child(condition_popup)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	condition_popup.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	UI.heading(box, "Stop on a condition", "Choose what to watch and when ECS should stop.")
	UI.hint(box, "Checks occur at system, command-flush, and completed unit boundaries. Changes entirely between boundaries can be missed.")
	box.custom_minimum_size.x = UI.px(440)
	condition_source = OptionButton.new()
	condition_source.add_item("Selected property")
	condition_source.add_item("Guided query")
	condition_source.item_selected.connect(func(_index: int): _condition_options())
	UI.field(box, "Watch", condition_source)
	condition_op = OptionButton.new()
	UI.field(box, "Stop when", condition_op)
	_condition_options()
	condition_value = LineEdit.new()
	condition_value.placeholder_text = 'e.g. 20, true, or "idle"'
	UI.field(box, "Comparison value", condition_value)
	step_limit = SpinBox.new()
	step_limit.min_value = 1
	step_limit.max_value = 100000
	step_limit.value = 1000
	step_limit.tooltip_text = "Stop after this many steps if the condition is not met."
	UI.field(box, "Maximum steps", step_limit)
	var bar := HFlowContainer.new()
	box.add_child(bar)
	_button(bar, "Add breakpoint", func(): _submit_condition(false))
	_button(bar, "Run until", func(): _submit_condition(true))
	_button(bar, "Close", func(): condition_popup.hide())

func _condition_options() -> void:
	condition_op.clear()
	for op in (["changed", "eq", "neq", "gt", "gte", "lt", "lte"] if condition_source.selected == 0 else ["nonempty", "empty", "entered", "left"]): condition_op.add_item(op)

func _submit_condition(run: bool) -> void:
	if condition_source.selected == 1 and query_editor.text != _generated:
		status.text = "Build a declarative query before arming a query condition"
		condition_popup.hide()
		return
	var condition := {"kind": "query", "spec": spec.duplicate(true), "op": condition_op.get_item_text(condition_op.selected)}
	if condition_source.selected == 0:
		var view := active_view()
		if view == null or not view.selected.has("field"):
			status.text = "Select an entity property first"
			return
		condition = {"kind": "property", "entity": view.ref, "component": view.selected.component, "property": view.selected.field.name, "op": condition.op}
		if condition.op != "changed":
			var parsed := _parse_value(condition_value.text)
			if parsed.has("error"):
				status.text = parsed.error
				return
			condition["value"] = Codec.encode(parsed.value)
	if run: model.request("run_until", {"condition": condition, "kind": transport.step_kind.selected, "limit": int(step_limit.value)})
	else: model.request("breakpoint", condition)
	condition_popup.hide()

func _picked_component() -> String:
	return str(component_picker.get_item_metadata(component_picker.selected)) if component_picker.selected >= 0 else ""

func _add_term(term: String) -> void:
	var path := _picked_component()
	if path != "":
		if not spec.has(term): spec[term] = []
		if not spec[term].has(path): spec[term].append(path)
		_generate_query()

func _class_name_for(path: String) -> String:
	for entry in model.catalogue:
		if entry.path == path: return entry.name
	return "load(%s)" % var_to_str(path)

func _generate_query() -> void:
	var text := "ECS.world.query"
	var terms: Array[String] = []
	for group in ["all", "any", "none"]:
		var components := {}
		for path in spec.get(group, []): components[path] = {}
		for prop in spec.get("properties", []):
			if prop.get("group", "all") != group: continue
			if not components.has(prop.component): components[prop.component] = {}
			if not components[prop.component].has(prop.property): components[prop.component][prop.property] = {}
			components[prop.component][prop.property][prop.op] = Codec.decode(prop.value)
		terms.clear()
		for path in components:
			terms.append(_class_name_for(path) if components[path].is_empty() else "{%s: %s}" % [_class_name_for(path), var_to_str(components[path])])
		if not terms.is_empty(): text += ".with_%s([%s])" % [group, ", ".join(terms)]
	if not spec.get("groups", []).is_empty(): text += ".with_group(%s)" % var_to_str(spec.groups)
	if spec.get("enabled", "any") != "any": text += ".%s()" % spec.enabled
	terms.clear()
	for rel in spec.get("relationships", []): terms.append("Relationship.new(%s.new(), null)" % _class_name_for(rel.component))
	if not terms.is_empty(): text += ".with_relationship([%s])" % ", ".join(terms)
	_generated = text
	query_editor.text = text
	_refresh_builder_terms()

func _columns() -> Array:
	var result: Array = []
	for part in columns_edit.text.split(",", false): result.append(part.strip_edges())
	return result.slice(0, 16)

func _run_query(remember := true) -> void:
	query_status.text = "Running query…"
	query_status.add_theme_color_override("font_color", UI.MUTED)
	var args := {"text": query_editor.text, "page": _page, "columns": _columns(), "filter": query_filter.text, "sort": _sort, "descending": _descending}
	if query_editor.text == _generated: args["spec"] = spec
	if model.request("query", args, {"key": "query_results"}) == 0: status.text = "Start the game to run a query"
	if remember:
		query_history.append(query_editor.text)
		if query_history.size() > 30: query_history.pop_front()
		query_history_picker.clear()
		for entry in query_history: query_history_picker.add_item(entry.left(50))
		query_history_picker.select(query_history.size() - 1)

func _watch_query() -> void:
	if query_editor.text != _generated:
		status.text = "Use the guided builder for a live query. Arbitrary expressions run only when you press Run."
		return
	_query_watch_sequence += 1
	var key := "query:" + (named_query.text if not named_query.text.is_empty() else str(_query_watch_sequence))
	model.watches[key] = {"key": key, "spec": spec.duplicate(true)}
	model.request("watch", model.watches[key])
	_refresh_watches()

func _refresh_browser() -> void:
	model.request("query", {"spec": {}, "filter": entity_filter.text, "page": _browser_page}, {"key": "browser"})

func _finished(op: String, result: Dictionary, context: Dictionary) -> void:
	if op == "overview": _overview_pending = 0
	if result.get("error", "") != "":
		status.text = str(result.error) + (" · %d changes applied before the failure" % result.applied if result.get("applied", 0) > 0 else "")
		if op == "scratchpad": output.text = result.error
		if op == "query" and context.get("key") == "query_results":
			query_status.text = "Query error · " + str(result.error)
			query_status.add_theme_color_override("font_color", UI.ERROR)
		return
	match op:
		"overview":
			overview.apply(result, _overview_manual_pending)
			_overview_manual_pending = false
		"snapshot_export":
			_snapshot_data = result.get("snapshot", {})
			_snapshot_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			_snapshot_file.title = "Export ECS snapshot"
			_snapshot_file.current_file = "world.gecs-state.json"
			_snapshot_file.popup_centered_ratio(0.65)
		"snapshot_preview":
			_restore_token = int(result.token)
			var rows: Array = result.get("rows", [])
			_restore_details.text = "%d value changes · %d entities checked · %d fields skipped\n\n" % [result.changes, result.entities, result.skipped] + "Restores component values and enabled states only.\nObserver side effects are not rolled back; a failure can leave a partial restore.\n\n" + "\n\n".join(rows) + ("\n\n…additional changes omitted from this summary" if int(result.changes) > rows.size() else "")
			_restore_dialog.get_ok_button().disabled = result.changes == 0
			_restore_dialog.popup_centered(Vector2i(UI.px(640), 0))
		"snapshot_restore":
			status.text = "Restored %d ECS values. ECS remains paused." % result.get("applied", 0)
			_refresh_browser()
		"resolve_saved": _restore_results(result)
		"query":
			var key := str(context.get("key", ""))
			if key == "restore":
				_restore_results(result)
				return
			var tree := browser if key == "browser" else query_results
			var selected_iid: int = int(tree.get_selected().get_metadata(0).get("iid", 0)) if tree.get_selected() else 0
			var expanded := {}
			var scroll := tree.get_scroll().y
			if key == "browser" and tree.get_root():
				for row in tree.get_root().get_children():
					var iid := int(row.get_metadata(0).get("iid", 0))
					expanded[iid] = not row.collapsed
					model.entities.erase(iid)
			tree.clear()
			var columns: Array = [] if key == "browser" else _columns()
			tree.columns = 2 if key == "browser" else 3 + columns.size()
			if key != "browser":
				tree.set_column_title(1, "Components")
				tree.set_column_title(2, "Relationships")
			for i in columns.size():
				tree.set_column_title(i + 3, columns[i])
				tree.set_column_clip_content(i + 3, true)
			var root := tree.create_item()
			for entity in result.get("rows", []):
				model.entities[int(entity.identity.iid)] = entity
				var row := tree.create_item(root)
				row.set_text(0, entity.name)
				row.set_metadata(0, entity.identity)
				if int(entity.identity.iid) == selected_iid: row.select(0)
				if key == "browser":
					row.set_text(1, "On" if entity.enabled else "Off")
					row.set_custom_color(1, UI.ACCENT if entity.enabled else UI.MUTED)
					row.collapsed = not expanded.get(int(entity.identity.iid), false)
					for group in ["component_names", "relationship_names"]:
						for title in entity.get(group, []):
							var detail := tree.create_item(row)
							detail.set_text(0, title)
							detail.set_metadata(0, entity.identity)
							detail.set_custom_color(0, UI.ACCENT if group == "relationship_names" else UI.MUTED)
				else:
					row.set_text(1, ", ".join(entity.get("component_names", [])))
					row.set_text(2, ", ".join(entity.get("relationship_names", [])))
					for col in [1, 2]: row.set_tooltip_text(col, row.get_text(col))
				for i in columns.size(): row.set_text(i + 3, entity.values.get(columns[i], {}).get("display", "—"))
			for child in tree.get_children(true):
				if child is VScrollBar: child.value = scroll
			if key == "browser": _browser_status.text = "%d matches · page %d" % [result.total, int(result.page) + 1]
			else: _query_rows = result.get("rows", [])
			if key != "browser": query_status.text = "%d matches · page %d · 100 rows per page" % [result.total, int(result.page) + 1]
		"scratchpad": output.text = result.get("value", {}).get("display", "Completed")
		"capture":
			_capture_options()
			status.text = "Captured %d entities. Capture again, then Compare." % result.get("entities", {}).size()
		"breakpoint": status.text = "Breakpoint %d armed" % result.get("id", 0)
		"run_until":
			status.text = result.get("reason", "Running until condition…")
			_cancel_run.visible = result.get("running", false)

func _updated(kind: String, data: Dictionary) -> void:
	match kind:
		"hello":
			session_label.text = str(data.get("world_path", "World"))
			session_label.tooltip_text = session_label.text
			status.text = "Connected · Session %d · %s" % [model.session_id + 1, session_label.text]
			component_picker.clear()
			for entry in model.catalogue:
				component_picker.add_item(entry.name)
				component_picker.set_item_metadata(component_picker.item_count - 1, entry.path)
			_refresh_transport()
			_refresh_browser()
		"step":
			_refresh_transport()
			model.refresh()
		"sample":
			for key in data.get("samples", {}): _latest_watches[key] = data.samples[key]
			_refresh_watches()
		"run":
			if data != _run_status and not str(data.get("reason", "")).is_empty(): status.text = data.reason
			_run_status = data.duplicate(true)
			_cancel_run.visible = data.get("running", false)
		"connection_error":
			status.text = data.error
			overview.set_state(data.error)
		"history_gap": status.text = "Some step history expired or exceeded the payload limit. Latest state is current."
		"edit", "scratchpad": _append_change(kind, data)
		"log": _append_log(data)
		"systems": _systems(data)
		"disconnected", "world_changed":
			_overview_pending = 0
			_overview_manual_pending = false
			_overview_last_pull = 0
			overview.set_state("Session ended" if kind == "disconnected" else "Connecting", kind == "world_changed")
			_latest_watches.clear()
			session_label.text = model.world_path
			_cancel_run.hide()
			_restore_dialog.hide()
			_restore_token = -1
			status.text = "Session ended · displayed values are frozen. Start the game to reconnect. Drafts are retained." if kind == "disconnected" else "Connecting to world…"
			transport.step_btn.disabled = true
			transport.pause_btn.disabled = true
			transport.resume_btn.disabled = true
			_update_connection_badge()

func _refresh_transport() -> void:
	transport.apply_state(model.step_state)
	var available := model.connected and model.world_id != 0 and not model.script_breaked
	transport.pause_btn.disabled = not available or transport.paused
	transport.resume_btn.disabled = not available or not transport.paused
	transport.step_btn.disabled = not available
	_update_connection_badge()
	if overview != null and model.connected:
		overview.set_state("Godot debugger break" if model.script_breaked else "ECS paused" if model.step_state.get("paused", false) else "Live")

func _update_connection_badge() -> void:
	if model == null or _connection_badge == null: return
	var caption := "Connecting…"
	var detail := "Waiting for the game world."
	var color := UI.WARNING
	if not model.connected:
		caption = "■ Session ended" if not model.ended_at.is_empty() else "○ No session"
		detail = "Session ended at %s. Displayed data is frozen; no live updates or runtime commands." % model.ended_at if not model.ended_at.is_empty() else "Run a scene from Godot to connect."
	elif model.world_id != 0:
		if model.script_breaked:
			caption = "● Godot break"
			detail = "Continue Godot’s script debugger before issuing ECS commands."
			color = UI.ERROR
		elif model.step_state.get("paused", false):
			caption = "Ⅱ ECS paused"
			detail = transport._status_text(model.step_state)
		else:
			caption = "● Connected · Live"
			detail = "Session %d · %s · ECS is running." % [model.session_id + 1, model.world_path]
			color = UI.ACCENT
	transport.status_label.text = caption
	transport.status_label.tooltip_text = detail + "\n" + model.world_path
	transport.status_label.add_theme_color_override("font_color", color)
	_connection_badge.add_theme_stylebox_override("panel", UI.style(Color(color, 0.10), 4, 4, Color(color, 0.35)))

func _fit_header() -> void:
	# Keep connection state legible on narrow/scaled windows. The badge tooltip
	# still exposes the full world path when there is no room for its label.
	var show_path := size.x >= UI.px(1120)
	_world_caption.visible = show_path
	session_label.visible = show_path

func open_entity(ref: Dictionary, remember := true) -> void:
	if ref.is_empty(): return
	nav.current_tab = 0
	for view in views:
		if view.ref == ref:
			if view.get_parent() == entity_tabs: entity_tabs.current_tab = view.get_index()
			elif view.get_window(): view.get_window().grab_focus()
			if remember: _remember_entity(ref)
			return
	var view := GECSExplorerEntityView.new()
	view.name = str(model.entities.get(int(ref.iid), {}).get("name", "Entity " + str(ref.id)))
	view.configure(model, ref)
	view.pinned = true
	view.open_entity.connect(open_entity)
	view.pin_requested.connect(func(item: Control):
		if item.get_parent() == entity_tabs: entity_tabs.set_tab_title(item.get_index(), item.name)
	)
	view.detach_requested.connect(_detach)
	views.append(view)
	entity_tabs.add_child(view)
	entity_tabs.current_tab = view.get_index()
	if remember: _remember_entity(ref)

func active_view() -> GECSExplorerEntityView:
	var control := entity_tabs.get_current_tab_control()
	return control if control is GECSExplorerEntityView else null

func _navigate(direction: int) -> void:
	var next := history_index + direction
	if next >= 0 and next < history.size():
		history_index = next
		open_entity(history[next], false)

func _close_active() -> void:
	var view := active_view()
	if view == null: return
	if not view.drafts.is_empty():
		status.text = "Apply or discard this entity’s drafts before closing it"
		return
	views.erase(view)
	view.release()
	entity_tabs.remove_child(view)
	view.queue_free()
	if entity_tabs.get_tab_count() == 1:
		entity_tabs.set_tab_hidden(0, false)
		entity_tabs.current_tab = 0

func _detach(view: Control) -> void:
	if view.get_parent() != entity_tabs: return
	var window := Window.new()
	window.visible = false
	window.title = "GECS · " + view.name
	window.force_native = true
	window.transient = false
	window.exclusive = false
	window.theme = UI.make_theme()
	window.size = Vector2i(1100, 650)
	window.min_size = Vector2i(700, 400)
	window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	add_child(window)
	var surface := PanelContainer.new()
	surface.add_theme_stylebox_override("panel", UI.style(UI.BACKGROUND, 14, 0))
	window.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.reparent(surface)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.close_requested.connect(func():
		view.reparent(entity_tabs)
		entity_tabs.current_tab = view.get_index()
		detached.erase(window)
		window.queue_free()
	)
	detached.append(window)
	window.show()

func _refresh_watches() -> void:
	var selected_key := str(watch_tree.get_selected().get_meta("key", "")) if watch_tree.get_selected() else ""
	watch_tree.clear()
	var root := watch_tree.create_item()
	for key in model.watches:
		var row := watch_tree.create_item(root)
		row.set_meta("key", key)
		if key == selected_key: row.select(0)
		var definition: Dictionary = model.watches[key]
		var watched_id: int = int(definition.get("entity", {}).get("iid", 0))
		var details: Dictionary = model.snapshots.get(watched_id, model.entities.get(watched_id, {}))
		var title: String = key.trim_prefix("query:") if definition.has("spec") else str(details.get("name", "Entity watch"))
		row.set_text(0, title)
		row.set_tooltip_text(0, key)
		row.set_metadata(0, definition)
		var samples: Array = model.series.get(key, [])
		var last: Dictionary = samples.back().data if not samples.is_empty() else {}
		row.set_text(1, last.get("error", "Watching" if model.connected else "Disconnected"))
		row.set_text(2, "%d matches" % int(last.get("total", 0)) if definition.has("spec") else "%d samples" % samples.size())
	for definition in _unresolved:
		var row := watch_tree.create_item(root)
		row.set_text(0, str(definition.get("alias", definition.get("path", "Saved watch"))))
		row.set_text(1, "Disconnected · choose Reconnect saved watches")
	if root.get_child_count() == 0:
		var empty := watch_tree.create_item(root)
		empty.set_text(0, "No watches yet")
		empty.set_text(1, "Open an entity or Watch query")
	_show_watch()

func _capture() -> void:
	var refs: Array = []
	for view in views:
		if view.pinned: refs.append(view.ref)
	model.request("capture", {"entities": refs})

func _compare() -> void:
	if model.captures.size() < 2:
		status.text = "Capture the investigation twice to compare before and after"
		return
	if _capture_before.item_count != model.captures.size(): _capture_options()
	var before: Dictionary = model.captures[maxi(0, _capture_before.selected)]
	var after: Dictionary = model.captures[maxi(0, _capture_after.selected)]
	_comparison_rows.clear()
	for diff in GECSExplorerModel.compare(before, after):
		var entity: Dictionary = after.get("entities", {}).get(str(diff.entity), before.get("entities", {}).get(str(diff.entity), {}))
		var label := str(entity.get("name", diff.entity)) + " / " + str(diff.field).get_file().replace(".gd:", " / ")
		_comparison_rows.append({"source": "Comparison", "field": label, "before": _display(diff.before), "after": _display(diff.after), "ref": entity.get("identity", {}), "path": diff.field})
	_change_mode.select(0)
	_render_changes()
	if _comparison_rows.is_empty(): _diff_title.text = "No differences between these captures."
	nav.current_tab = 4

func _display(value: Variant) -> String:
	if value is Dictionary and value.has("type") and value.get("editable", false):
		var decoded: Variant = Codec.decode(value)
		return JSON.stringify(decoded, "  ") if decoded is Array or decoded is Dictionary else var_to_str(decoded)
	return JSON.stringify(value, "  ") if value is Dictionary or value is Array else str(value)

func _add_change_row(source: String, field: String, before: String, after: String, ref: Dictionary = {}, property_path := "") -> void:
	_activity_rows.append({"source": source, "field": field, "before": before, "after": after, "ref": ref, "path": property_path})
	if _activity_rows.size() > 400: _activity_rows.pop_front()
	if _change_mode.selected == 1: _draw_change_row(_activity_rows.back())

func _draw_change_row(entry: Dictionary) -> void:
	var root := changes_tree.get_root()
	if root.get_child_count() >= 400: root.get_first_child().free()
	var row := changes_tree.create_item(root)
	for i in 4:
		row.set_text(i, [entry.source, entry.field, entry.before, entry.after][i])
		row.set_tooltip_text(i, row.get_text(i))
	row.set_custom_color(2, UI.ERROR)
	row.set_custom_color(3, UI.ACCENT)
	row.set_metadata(0, entry.ref)
	row.set_meta("property_path", entry.path)

func _append_change(kind: String, data: Dictionary) -> void:
	if kind == "edit":
		var before: Dictionary = data.get("before", {})
		var after: Dictionary = data.get("after", {})
		var ref: Dictionary = before.get("identity", {})
		for diff in GECSExplorerModel.compare({"entities": {"entity": before}}, {"entities": {"entity": after}}):
			_add_change_row("Editor edit", diff.field, _display(diff.before), _display(diff.after), ref, diff.field)
	else: _add_change_row("Scratchpad", "Explicit execution", "", data.get("result", {}).get("display", ""))

func _append_log(log: Dictionary) -> void:
	for op in log.get("ops", []):
		if op.size() < 9: continue
		var ref: Dictionary = model.entities.get(int(op[1]), {}).get("identity", {})
		_add_change_row("#%s %s %s" % [log.get("step_id", 0), op[8], op[7]], "%s · %s.%s" % [op[2], op[3], op[4]], str(op[5]), str(op[6]), ref)

func _systems(data: Dictionary) -> void:
	_systems_data = data
	var selected_id: int = systems_tree.get_selected().get_metadata(0).id if systems_tree.get_selected() else 0
	var root := systems_tree.get_root()
	if root == null: root = systems_tree.create_item()
	for id in _system_items.keys():
		if not data.has(id):
			_system_items[id].free()
			_system_items.erase(id)
	var rows: Array = []
	var total := 0.0
	for id in data:
		var system: Dictionary = data[id]
		var metrics: Dictionary = system.get("last_run_data", {})
		var last: float = metrics.get("execution_time_ms", 0.0)
		var title := str(metrics.get("system_name", system.get("path", "")))
		var values := [title, str(system.get("group", "")), last, metrics.get("min_ms", last), metrics.get("max_ms", last), metrics.get("avg_ms", last), metrics.get("entity_count", 0), metrics.get("archetype_count", 0), metrics.get("execution_order", 0), "Paused" if system.get("paused", false) else "Active" if system.get("active", true) else "Disabled"]
		rows.append({"id": id, "values": values, "active": system.get("active", true), "script": metrics.get("script_path", ""), "metrics": metrics})
		if system.get("active", true): total += last
	rows.sort_custom(func(a, b): return a.values[_system_sort] > b.values[_system_sort] if _system_descending else a.values[_system_sort] < b.values[_system_sort])
	var fastest: Dictionary = {}
	var slowest: Dictionary = {}
	for entry in rows:
		if entry.active and not entry.metrics.is_empty():
			if fastest.is_empty() or entry.values[2] < fastest.values[2]: fastest = entry
			if slowest.is_empty() or entry.values[2] > slowest.values[2]: slowest = entry
		var row: TreeItem = _system_items.get(entry.id)
		if row == null:
			row = systems_tree.create_item(root)
			_system_items[entry.id] = row
		if int(entry.id) == selected_id: row.select(0)
		row.set_metadata(0, entry)
		for i in 10:
			row.set_text(i, String.num(float(entry.values[i]), 4) if i in [2, 3, 4, 5] else str(entry.values[i]))
			row.set_tooltip_text(i, row.get_text(i))
		row.set_custom_color(9, UI.ACCENT if entry.active else UI.MUTED)
		row.set_tooltip_text(0, entry.script + "\n" + JSON.stringify(entry.metrics, "  "))
	# Move existing rows once after applying the digest; retain selection and scroll.
	for i in range(rows.size() - 1, -1, -1):
		var row: TreeItem = _system_items[rows[i].id]
		if root.get_first_child() != row: row.move_before(root.get_first_child())
	_system_summary.text = "%d systems · total last run %.4f ms" % [rows.size(), total]
	if not slowest.is_empty(): _system_summary.text += " · Slowest: %s (%.4f ms) · Fastest: %s (%.4f ms)" % [slowest.values[0], slowest.values[2], fastest.values[0], fastest.values[2]]
	_system_summary.clip_text = true
	_system_summary.tooltip_text = _system_summary.text

func _process(_delta: float) -> void:
	if status != null and status.text != _last_status:
		_last_status = status.text
		status.tooltip_text = status.text
		_status_history.push_front(Time.get_time_string_from_system() + "  " + status.text)
		if _status_history.size() > 50: _status_history.pop_back()

## Called by the session scheduler, not by individual panels' timers.
func _poll_requests() -> Array:
	var polls: Array = []
	if nav == null: return polls
	if _visible(systems_tree): polls.append({"op": "systems"})
	if _visible(browser): polls.append({"op": "query", "args": {"spec": {}, "filter": entity_filter.text, "page": _browser_page}, "context": {"key": "browser"}})
	if _visible(overview) and not overview.frozen:
		polls.append({"op": "overview", "args": {"limit": overview.row_limit}, "interval": overview.interval_ms})
	var keys := {}
	if _visible(watch_tree):
		for key in model.watches: keys[key] = true
	for view in views:
		if not is_instance_valid(view) or view.ref.get("world") != model.world_id or view.ref.get("epoch") != model.epoch: continue
		if _visible(view): keys[view._watch_key] = true
		if view.graph_toggle and view.graph_toggle.button_pressed and _visible(view.graph_panel) and view.graph_panel.show_live_check.button_pressed:
			polls.append({"op": "graph", "args": {"id": view.graph_id}, "context": {"key": "graph:%d" % view.graph_id}})
	for key in keys.keys():
		if not model.watches.has(key): keys.erase(key)
	if not keys.is_empty(): polls.append({"op": "sample", "args": {"keys": keys.keys()}})
	return polls

static func _visible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree(): return false
	# A native window has its own visibility, independent of its hidden owner
	# in the editor. Follow local tab visibility up to that window, never focus.
	var node: Node = control
	while node != null:
		if node is CanvasItem and not node.visible: return false
		if node is Window:
			if not node.visible: return false
			if node.force_native or not node.is_embedded(): return true
		node = node.get_parent()
	return true

func _request_overview(manual: bool) -> void:
	if model == null or not model.connected or model.world_id == 0 or model.script_breaked: return
	if _overview_pending != 0 or model.has_pending("overview"): return
	_overview_last_pull = Time.get_ticks_msec()
	_overview_manual_pending = manual
	_overview_pending = model.request("overview", {"limit": overview.row_limit})

func _parse_value(text: String) -> Dictionary:
	var expression := Expression.new()
	if expression.parse(text) != OK: return {"error": expression.get_error_text()}
	var value: Variant = expression.execute([], null, false)
	return {"error": expression.get_error_text()} if expression.has_execute_failed() else {"value": value}

func _saved_options() -> void:
	saved_picker.clear()
	for name in saved.get("queries", {}): saved_picker.add_item(name)

func _save_setup() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/editor")
	var file := FileAccess.open(PREFS, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(saved, "\t"))

func _load_setup(data: Dictionary) -> void:
	if not data.get("queries", {}) is Dictionary or not data.get("snippets", {}) is Dictionary or not data.get("watches", []) is Array: return
	saved = {"queries": data.get("queries", {}), "snippets": data.get("snippets", {}), "watches": data.get("watches", [])}
	if data.get("overview") is Dictionary:
		overview.load_preferences(data.overview)
		saved["overview"] = overview.preferences()
	_unresolved = saved.watches.filter(func(w): return w is Dictionary and not w.has("spec"))
	_saved_options()
	_refresh_watches()
	status.text = "Saved setup loaded. Queries and snippets run only when requested. Reconnect saved watches from Watches."

func _save_pins() -> void:
	saved.watches = []
	for view in views:
		if not view.pinned: continue
		var alias := str(view.snapshot.get("alias", ""))
		var path := str(view.snapshot.get("path", ""))
		if alias != "" or path != "":
			saved.watches.append({"alias": alias, "path": path, "script": view.snapshot.get("script", ""), "layout": view.layout_definition()})
	for key in model.watches:
		if model.watches[key].has("spec"): saved.watches.append({"key": key, "spec": model.watches[key].spec})
	_save_setup()
	status.text = "Pinned setup saved by alias or node path; runtime IDs and drafts are not saved"

func _restore_pins() -> void:
	model.request("resolve_saved", {"definitions": saved.watches.filter(func(w): return w is Dictionary and not w.has("spec"))}, {"key": "restore"})

func _restore_results(result: Dictionary) -> void:
	_unresolved.clear()
	for watch in saved.get("watches", []):
		if watch is Dictionary and watch.has("spec") and watch.has("key"):
			model.watches[watch.key] = watch
			model.request("watch", watch)
	for row in result.get("rows", []):
		if row.has("error"):
			_unresolved.append(row.definition)
			continue
		var entity: Dictionary = row.entity
		model.entities[int(entity.identity.iid)] = entity
		open_entity(entity.identity)
		var view := active_view()
		view.pinned = true
		view.pending_layout = row.definition.get("layout", {})
		view._restore_layout()
	status.text = "%d saved entity watches remain disconnected" % _unresolved.size()
	_refresh_watches()

func _choose_file(importing: bool) -> void:
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.popup_centered_ratio(0.6)

func _file_selected(path: String) -> void:
	if _file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 2097152:
			status.text = "Cannot import this setup file"
			return
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			_load_setup(data)
			_save_setup()
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(saved, "\t"))

func _remember_entity(ref: Dictionary) -> void:
	if history_index >= 0 and history[history_index] == ref: return
	history = history.slice(0, history_index + 1)
	history.append(ref)
	if history.size() > 100: history.pop_front()
	history_index = history.size() - 1

func _entity_actions(parent: Control, tree: Tree) -> void:
	var actions := MenuButton.new()
	actions.text = "⋯"
	actions.tooltip_text = "Actions for the selected entity"
	parent.add_child(actions)
	var popup := actions.get_popup()
	for label in ["Open tab", "Include in captures", "Reveal Remote Node", "Open Script", "Break when touched"]: popup.add_item(label)
	popup.id_pressed.connect(func(id: int):
		var row := tree.get_selected()
		if row == null: return
		var ref: Dictionary = row.get_metadata(0)
		match id:
			0: open_entity(ref)
			1:
				open_entity(ref)
				active_view().pinned = true
			2: model.reveal(ref)
			3:
				var path := str(model.entities.get(int(ref.iid), {}).get("script", ""))
				if path != "" and Engine.is_editor_hint(): EditorInterface.edit_script(load(path))
			4: model.sender.call("gecs:breakpoint_add", [{"kind": "entity", "entity": ref.iid}])
	)
	UI.context_menu(tree, func(): return {
		"Open tab": func(): popup.id_pressed.emit(0),
		"Include in captures": func(): popup.id_pressed.emit(1),
		"Reveal Remote Node": func(): popup.id_pressed.emit(2),
		"Open script": func(): popup.id_pressed.emit(3),
		"Break when touched": func(): popup.id_pressed.emit(4)
	})

func _focus_change() -> void:
	var row := changes_tree.get_selected()
	if row == null or not row.get_metadata(0) is Dictionary or not row.get_metadata(0).has("iid"): return
	open_entity(row.get_metadata(0))
	var view := active_view()
	view.pending_property_path = str(row.get_meta("property_path", ""))
	view._focus_pending_property()

func _tab_menu() -> void:
	var view := active_view()
	if view == null: return
	var popup := PopupMenu.new()
	add_child(popup)
	popup.add_check_item("Include in captures / saved setup", 0)
	popup.set_item_checked(0, view.pinned)
	popup.add_item("Detach tab", 1)
	popup.add_item("Reveal Remote Node", 2)
	popup.add_separator()
	popup.add_item("Close tab", 3)
	popup.id_pressed.connect(func(id: int):
		match id:
			0: view.pinned = not view.pinned
			1: _detach(view)
			2: model.reveal(view.ref)
			3: _close_active()
	)
	popup.popup_hide.connect(popup.queue_free)
	popup.position = DisplayServer.mouse_get_position()
	popup.popup()

func _require_snapshot_session() -> bool:
	if not model.connected or model.world_id == 0:
		status.text = "Start the game before exporting or restoring an ECS snapshot."
		return false
	if model.script_breaked or not model.step_state.get("paused", false):
		status.text = "Pause ECS before exporting or restoring a snapshot. Continue Godot’s debugger first if it is stopped."
		return false
	return true

func _snapshot_file_selected(path: String) -> void:
	if _snapshot_file.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var contents := JSON.stringify(_snapshot_data, "  ")
		if contents.to_utf8_buffer().size() > 8388608:
			status.text = "Snapshot JSON exceeds 8 MiB; no file written."
			return
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			status.text = "Could not write snapshot: " + error_string(FileAccess.get_open_error())
			return
		file.store_string(contents)
		file.flush()
		status.text = "Exported %d entities to %s" % [_snapshot_data.get("entities", []).size(), path] if file.get_error() == OK else "Snapshot write failed."
		_snapshot_data = {}
	else:
		if not _require_snapshot_session(): return
		if not _require_clean_drafts(): return
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 8388608:
			status.text = "Cannot read snapshot (maximum 8 MiB)."
			return
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			status.text = "Invalid snapshot JSON."
			return
		status.text = "Checking snapshot compatibility; no values have been changed."
		model.request("snapshot_preview", {"snapshot": parsed})

func _require_clean_drafts() -> bool:
	for view in views:
		if not view.drafts.is_empty():
			status.text = "Apply or discard local drafts before restoring a snapshot."
			return false
	return true
