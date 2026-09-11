@tool
class_name GECSExplorerEntityView
extends VBoxContainer
const UI = preload("res://addons/gecs/debug/explorer/gecs_explorer_ui.gd")

signal open_entity(ref: Dictionary)
signal pin_requested(view: Control)
signal detach_requested(view: Control)

var model: GECSExplorerModel
var ref: Dictionary = {}
var snapshot: Dictionary = {}
var drafts: Array = []
var pinned := false
var graph_id := 0
var graph_panel: GECSEditorGraphPanel
var chart: GECSExplorerChart
var tree: Tree
var feedback: Label
var _live_hint: Label
var filter: LineEdit
var advanced: CheckBox
var inspector: Control
var proxy: GECSExplorerPropertyProxy
var fallback: LineEdit
var selected: Dictionary = {}
var chart_property: Dictionary = {}
var apply_step: Button
var component_picker: OptionButton
var target_picker: OptionButton
var graph_toggle: CheckButton
var _data_split: VSplitContainer
var _split: HSplitContainer
var _sidebar: VBoxContainer
var _watch_key := ""
var _busy := false
var _released := false
var _rendering := false
var _previous: Dictionary = {}
var chart_toggle: CheckButton
var draft_list: ItemList
var _buttons: Array[Button] = []
var pending_layout: Dictionary = {}
var _entity_title: Label
var _entity_path: Label
var _property_title: Label
var _property_help: Label
var _component_count: Label
var _draft_title: Label
var _draft_card: Control
var _graph_card: Control
var _chart_card: Control
var _structure_popup: PopupPanel
var _pin_button: Button
var _property_actions: HFlowContainer
var _conflict_actions: HFlowContainer
var _initial_graph := true
var _graph_height := 360.0
var _graph_resizing := false
var _graph_resize_handle: Label
var _graph_window: Window
var _graph_popout: Button
var _watch_button: Button
var _save_button: Button
var chart_properties: Array = []
var _extra_charts: Array = []
var _editor_card: Control
var _chart_focus: Button
var _chart_body: VBoxContainer
var relationship_tree: Tree
var _relationship_count: Label
var _relationships_empty: Label
var pending_property_path := ""

func configure(session: GECSExplorerModel, identity: Dictionary) -> void:
	model = session
	ref = identity
	_watch_key = "entity:%s:%s:%s" % [ref.world, ref.epoch, ref.iid]
	model.updated.connect(_updated)
	model.request_finished.connect(_finished)
	if is_node_ready(): _connect_watch()

func _ready() -> void:
	add_theme_constant_override("separation", UI.px(6))
	var identity := HBoxContainer.new()
	add_child(identity)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", UI.px(3))
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(names)
	_entity_title = UI.label(names, "Entity", 17)
	_entity_title.hide() # The tab already names this entity.
	_entity_path = UI.label(names, "Loading live data…", 12, UI.MUTED)
	_entity_path.clip_text = true
	_entity_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pin_button = _button(identity, "Pin", func():
		pinned = not pinned
		_update_identity()
		pin_requested.emit(self)
	)
	_pin_button.hide() # Pinning belongs to the tab context menu.
	UI.menu(identity, "Entity ▾", ["Reveal in Remote Scene Tree", "Open entity script", "Detach entity", "Break when touched", "Enable / disable entity"], [
		func(): model.reveal(ref),
		func(): _open_script(snapshot.get("script", "")),
		func(): detach_requested.emit(self),
		func(): model.sender.call("gecs:breakpoint_add", [{"kind": "entity", "entity": ref.iid}]),
		func(): _stage({"op": "enabled", "expected": snapshot.get("enabled", true), "value": not snapshot.get("enabled", true)})
	])
	graph_toggle = CheckButton.new()
	add_child(graph_toggle)
	graph_toggle.hide()
	graph_toggle.toggled.connect(_toggle_graph)
	chart_toggle = CheckButton.new()
	add_child(chart_toggle)
	chart_toggle.hide()
	chart_toggle.toggled.connect(func(value: bool):
		chart.visible = false
		_chart_card.visible = value
		if not value and _editor_card != null:
			_editor_card.show()
			if _chart_focus != null: _chart_focus.text = "Focus"
		for entry in _extra_charts: entry.node.visible = value
		if value and chart_properties.is_empty(): feedback.text = "Select a numeric property, then Add chart. Add more properties for multiple charts."
	)
	var view_menu := UI.menu(identity, "Views ▾", ["Relationship map", "Property charts"], [
		func(): graph_toggle.button_pressed = not graph_toggle.button_pressed,
		func(): chart_toggle.button_pressed = not chart_toggle.button_pressed
	])
	for index in 2: view_menu.get_popup().set_item_as_checkable(index, true)
	view_menu.get_popup().about_to_popup.connect(func():
		view_menu.get_popup().set_item_checked(0, graph_toggle.button_pressed)
		view_menu.get_popup().set_item_checked(1, chart_toggle.button_pressed)
	)
	_split = HSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	var data := VSplitContainer.new()
	_data_split = data
	data.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	data.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data.size_flags_stretch_ratio = 1.8
	_split.add_child(data)
	data.get_drag_area_control().tooltip_text = "Drag to resize Components and Relationships"
	var components := UI.card(data, "", "", true)
	var table_header := UI.heading(components, "Components", "Select a property to inspect, edit, or watch it.")
	_component_count = UI.label(table_header, "", 12, UI.MUTED)
	_button(table_header, "+ Add", func(): _structure_popup.popup_centered(Vector2i(UI.px(460), 0)))
	var search := HBoxContainer.new()
	components.add_child(search)
	filter = LineEdit.new()
	filter.placeholder_text = "Search properties…"
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter.text_changed.connect(func(_text: String): _render())
	search.add_child(filter)
	advanced = CheckBox.new()
	advanced.text = "Internal"
	advanced.tooltip_text = "Include non-exported script variables. Engine bookkeeping remains read-only."
	advanced.toggled.connect(func(_value: bool): _render())
	search.add_child(advanced)
	tree = Tree.new()
	tree.columns = 4
	tree.select_mode = Tree.SELECT_ROW
	tree.hide_root = true
	tree.column_titles_visible = true
	for i in 4:
		tree.set_column_title(i, ["Property", "Live value", "Staged", "Status"][i])
		tree.set_column_clip_content(i, true)
	tree.set_column_expand_ratio(0, 3)
	tree.set_column_expand_ratio(1, 2)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = UI.px(90)
	tree.item_selected.connect(_selected)
	components.add_child(tree)
	tree.item_activated.connect(func():
		if selected.has("target") and not selected.target.is_empty(): open_entity.emit(selected.target)
	)
	UI.context_menu(tree, _property_context)
	_live_hint = UI.hint(components, "LIVE DATA   •   Values refresh automatically. Drafts stay yours until applied.")
	var relations := UI.card(data, "", "", true)
	relations.get_parent().size_flags_stretch_ratio = 0.3
	var relations_heading := UI.heading(relations, "Relationships")
	relations_heading.tooltip_text = "Drag the divider above to resize the relationship table."
	_relationship_count = UI.label(relations_heading, "", 12, UI.MUTED)
	_button(relations_heading, "+ Add", func(): _structure_popup.popup_centered(Vector2i(UI.px(460), 0)))
	relationship_tree = Tree.new()
	relationship_tree.columns = 3
	relationship_tree.hide_root = true
	relationship_tree.select_mode = Tree.SELECT_ROW
	relationship_tree.column_titles_visible = true
	relationship_tree.set_column_title(0, "Direction")
	relationship_tree.set_column_expand(0, false)
	relationship_tree.set_column_custom_minimum_width(0, UI.px(124))
	relationship_tree.set_column_title(1, "Relation")
	relationship_tree.set_column_title(2, "Entity · double-click to open")
	relationship_tree.custom_minimum_size.y = UI.px(70)
	relationship_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	relationship_tree.item_activated.connect(_open_relationship)
	relations.add_child(relationship_tree)
	_relationships_empty = UI.hint(relations, "No incoming or outgoing relationships. Add a relation, or link to this entity from another entity.")
	UI.context_menu(relationship_tree, _relationship_context)
	var draft_body := UI.card(self)
	_draft_card = draft_body.get_parent()
	_draft_card.hide()
	_draft_title = UI.label(draft_body, "Staged changes", 16, UI.WARNING)
	_draft_title.clip_text = true
	draft_list = ItemList.new()
	draft_list.custom_minimum_size.y = UI.px(54)
	draft_body.add_child(draft_list)
	var actions := HFlowContainer.new()
	draft_body.add_child(actions)
	apply_step = _button(actions, "Apply & Step", func(): _apply(true))
	apply_step.theme_type_variation = "ExplorerPrimary"
	apply_step.tooltip_text = "Apply staged changes, then advance one selected step. Pause ECS first."
	_button(actions, "Discard drafts", func():
		drafts.clear()
		_render()
		_selected()
	)
	_conflict_actions = HFlowContainer.new()
	draft_body.add_child(_conflict_actions)
	_button(_conflict_actions, "Refresh draft bases", _refresh_bases).tooltip_text = "Keep staged values, but compare them against the latest live values."
	_button(_conflict_actions, "Replace conflicting values", func(): _apply(false, true)).tooltip_text = "Explicitly overwrite values that changed after you started editing."
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = UI.px(285)
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_split.add_child(side_scroll)
	_sidebar = VBoxContainer.new()
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_sidebar)
	var editor := UI.card(_sidebar)
	_editor_card = editor.get_parent()
	UI.label(editor, "PROPERTY INSPECTOR", 11, UI.ACCENT)
	_property_title = UI.label(editor, "Choose a property", 18)
	_property_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_property_help = UI.hint(editor, "Click a value in the component table. Its editor and watch actions will appear here.")
	proxy = GECSExplorerPropertyProxy.new()
	proxy.staged.connect(func(property: String, value: Variant): _stage_property(property, value))
	if Engine.is_editor_hint():
		inspector = EditorInspector.new()
		inspector.custom_minimum_size.y = UI.px(90)
		inspector.visible = false
		editor.add_child(inspector)
	else:
		fallback = LineEdit.new()
		fallback.placeholder_text = "New value · Enter to stage"
		fallback.text_submitted.connect(_stage_expression)
		fallback.visible = false
		editor.add_child(fallback)
	_property_actions = HFlowContainer.new()
	_property_actions.visible = false
	editor.add_child(_property_actions)
	_watch_button = _button(_property_actions, "+ Add chart", func(): add_chart(selected))
	UI.menu(_property_actions, "More ▾", ["Open component script", "Inspect object reference", "Remove component"], [
		func(): _open_script(selected.get("script", "")),
		func():
			var field: Dictionary = selected.get("field", {})
			if field.get("value", {}).has("object_id"): model.sender.call("scene:inspect_objects", [[field.value.object_id], true]),
		func():
			if selected.has("component"): _stage({"op": "remove_component", "component": selected.component})
	])
	var save_bar := HFlowContainer.new()
	editor.add_child(save_bar)
	_save_button = _button(save_bar, "Apply to game", func():
		if fallback != null and fallback.visible: _stage_expression(fallback.text)
		_apply(false)
	)
	_save_button.theme_type_variation = "ExplorerPrimary"
	_save_button.tooltip_text = "Save staged component changes to the running game."
	feedback = UI.hint(editor, "Edits affect the running game. Project scenes and resources are not saved.")
	_draft_card.reparent(editor)
	_draft_card.add_theme_stylebox_override("panel", UI.style(UI.INSET, 8, 5))
	var chart_body := UI.card(_sidebar)
	_chart_body = chart_body
	_chart_card = chart_body.get_parent()
	_chart_card.hide()
	var chart_header := UI.heading(chart_body, "Property charts", "Add another property to compare signals · 10 Hz")
	_chart_focus = _button(chart_header, "Focus", func():
		_editor_card.visible = not _editor_card.visible
		_chart_focus.text = "Inspector" if not _editor_card.visible else "Focus"
	)
	_chart_focus.tooltip_text = "Give multiple charts the full sidebar height. Select a property to return to editing."
	_button(chart_header, "×", func():
		chart_toggle.button_pressed = false
		_editor_card.show()
		_chart_focus.text = "Focus"
	).tooltip_text = "Close chart"
	chart = GECSExplorerChart.new()
	chart.custom_minimum_size = Vector2(0, UI.px(170))
	chart.visible = false
	chart_body.add_child(chart)

	var graph_body := UI.card(_sidebar, "", "", true)
	_graph_card = graph_body.get_parent()
	_graph_card.hide()
	var graph_header := UI.heading(graph_body, "Relationships", "Double-click an entity to open it. Drag nodes to arrange.")
	_graph_popout = _button(graph_header, "Open in window", _open_graph_window)
	_button(graph_header, "×", func(): graph_toggle.button_pressed = false).tooltip_text = "Close relationship map"
	graph_panel = GECSEditorGraphPanel.new()
	graph_panel.visible = false
	graph_panel.custom_minimum_size.y = UI.px(_graph_height)
	graph_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_body.add_child(graph_panel)
	# Keep graph controls local and concise; the entity is already the watch set.
	graph_panel.get_child(0).hide()
	for property in graph_panel.graph.get_property_list():
		if property.name in ["show_grid_buttons", "show_minimap_button", "show_arrange_button", "show_zoom_label"]: graph_panel.graph.set(property.name, false)
	graph_panel.graph.add_theme_stylebox_override("panel", UI.style(UI.INSET, 0, 6))
	var graph_tools := HFlowContainer.new()
	graph_body.add_child(graph_tools)
	graph_body.move_child(graph_tools, 1)
	graph_panel.show_live_check.reparent(graph_tools)
	graph_panel.show_live_check.text = "Live"
	_button(graph_tools, "Frame nodes", _frame_graph)
	var depth := UI.menu(graph_tools, "Depth ▾", ["This entity", "1 relationship hop", "2 relationship hops", "3 relationship hops"], [
		func(): graph_panel.depth_spin.value = 0,
		func(): graph_panel.depth_spin.value = 1,
		func(): graph_panel.depth_spin.value = 2,
		func(): graph_panel.depth_spin.value = 3
	])
	depth.tooltip_text = "How far to follow relationships from this entity."
	_graph_resize_handle = UI.label(graph_body, "↕  Drag to resize graph", 12, UI.MUTED)
	_graph_resize_handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_graph_resize_handle.custom_minimum_size.y = UI.px(24)
	_graph_resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_graph_resize_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_graph_resize_handle.tooltip_text = "Drag vertically for height. Drag the divider beside the component table for width, or open in a resizable window."
	_graph_resize_handle.gui_input.connect(_resize_graph_input)
	_build_structure_dialog()
	if model != null:
		_setup_catalogue()
		graph_panel.send = model.sender
		graph_panel.selected_entities_provider = func(): return [ref.iid]
		graph_panel.entity_activated.connect(_graph_activated)
		_connect_watch()
	_render()

func _build_structure_dialog() -> void:
	_structure_popup = PopupPanel.new()
	add_child(_structure_popup)
	var body := VBoxContainer.new()
	_structure_popup.add_child(body)
	UI.heading(body, "Add to entity", "Structural changes are staged for review before you apply them.")
	component_picker = OptionButton.new()
	component_picker.fit_to_longest_item = false
	component_picker.custom_minimum_size.x = UI.px(320)
	UI.field(body, "Component type", component_picker)
	target_picker = OptionButton.new()
	target_picker.fit_to_longest_item = false
	UI.field(body, "Relationship target", target_picker, "Used only when adding a relationship.")
	var actions := HFlowContainer.new()
	body.add_child(actions)
	_button(actions, "Add component", func():
		if component_picker.selected >= 0:
			_stage({"op": "add_component", "script": component_picker.get_item_metadata(component_picker.selected)})
			_structure_popup.hide()
	).theme_type_variation = "ExplorerPrimary"
	_button(actions, "Add relationship", func():
		if component_picker.selected >= 0 and target_picker.selected >= 0:
			_stage({"op": "add_relationship", "script": component_picker.get_item_metadata(component_picker.selected), "target": target_picker.get_item_metadata(target_picker.selected)})
			_structure_popup.hide()
	)
	_button(actions, "Cancel", func(): _structure_popup.hide())

func _update_identity() -> void:
	_entity_title.text = str(snapshot.get("name", name))
	_entity_path.text = str(snapshot.get("path", "Entity #" + str(ref.get("id", 0))))
	_entity_path.tooltip_text = _entity_path.text
	_pin_button.text = "Pinned" if pinned else "Pin"
	_component_count.text = str(snapshot.get("components", []).size())
	if get_parent() is TabContainer and get_index() < get_parent().get_tab_bar().tab_count:
		var tabs := get_parent() as TabContainer
		tabs.set_tab_title(get_index(), str(snapshot.get("name", name)) + (" •" if not drafts.is_empty() else ""))
		tabs.set_tab_tooltip(get_index(), _entity_path.text + "\nRight-click for capture, detach, and navigation actions.")

func _frame_graph() -> void:
	graph_panel._on_arrange()
	var first := Vector2(INF, INF)
	for node in graph_panel.graph.get_children():
		if node is GraphNode: first = first.min(node.position_offset)
	if first.x != INF: graph_panel.graph.scroll_offset = first * graph_panel.graph.zoom - Vector2(UI.px(20), UI.px(50))

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := UI.button(parent, text, callback)
	_buttons.append(button)
	return button

func _setup_catalogue() -> void:
	component_picker.clear()
	for entry in model.catalogue:
		component_picker.add_item(entry.name)
		component_picker.set_item_metadata(component_picker.item_count - 1, entry.path)
	target_picker.clear()
	target_picker.add_item("Wildcard target")
	target_picker.set_item_metadata(0, {})
	for entity in model.entities.values():
		if not entity.has("identity"): continue
		target_picker.add_item(entity.name)
		target_picker.set_item_metadata(target_picker.item_count - 1, entity.identity)

func _finished(op: String, result: Dictionary, context: Dictionary) -> void:
	if context.get("key") != _watch_key: return
	if op == "inspect":
		if result.has("identity"):
			_previous = snapshot
			snapshot = result
			_restore_layout()
		else: feedback.text = result.get("error", "Entity unavailable")
	elif op == "apply":
		_busy = false
		var applied := int(result.get("applied", 0))
		drafts = drafts.slice(applied)
		if result.has("snapshot"): snapshot = result.snapshot
		feedback.text = str(result.get("error", "")) if result.get("error", "") != "" else "Applied %d edits" % applied
	_render()
	if op == "apply": _selected()

func _updated(kind: String, data: Dictionary) -> void:
	if kind == "sample" and data.get("samples", {}).has(_watch_key):
		var next: Dictionary = data.samples[_watch_key]
		if next.has("identity"):
			_previous = snapshot
			snapshot = next
			_render()
		else: feedback.text = next.get("error", "Entity unavailable")
		_update_chart()
	elif kind == "step":
		_render()
	elif kind == "graph" and data.get("id") == graph_id:
		graph_panel.apply_graph(data.step, data.graph)
		if _initial_graph and not data.graph.get("nodes", []).is_empty():
			_initial_graph = false
			_frame_graph.call_deferred()
	elif kind in ["disconnected", "world_changed"]:
		_live_hint.text = "FROZEN DATA   •   Session ended or world changed. Drafts retained."
		_busy = false
		for button in _buttons:
			if button.text in ["Apply", "Apply to game", "Apply & Step", "Replace conflicting values"]: button.disabled = true
		feedback.text = "Disconnected — drafts retained; reconnect this entity before applying"

func _render() -> void:
	if tree == null: return
	var live: bool = model.connected and ref.get("world") == model.world_id and ref.get("epoch") == model.epoch
	_live_hint.text = ("ECS PAUSED   •   " if model.step_state.get("paused", false) else "LIVE DATA   •   ") + "Drafts stay yours until applied." if live else "FROZEN DATA   •   Session ended or world changed. Drafts retained."
	_rendering = true
	var scroll: float = tree.get_scroll().y
	var expanded: Dictionary = {}
	if tree.get_root():
		for child in tree.get_root().get_children(): expanded[child.get_meta("key", "")] = not child.collapsed
	tree.clear()
	var root := tree.create_item()
	for comp in snapshot.get("components", []):
		var row := tree.create_item(root)
		row.set_meta("key", comp.script)
		row.set_metadata(0, {"component": comp.iid, "script": comp.script})
		row.set_text(0, comp.name)
		row.set_custom_color(0, UI.ACCENT)
		for col in 4: row.set_custom_bg_color(col, UI.SURFACE)
		row.collapsed = not expanded.get(comp.script, true)
		if selected.get("component") == comp.iid and not selected.has("field"): row.select(0)
		var visible_count := 0
		for field in comp.fields:
			if not advanced.button_pressed and not field.exported: continue
			if not filter.text.is_empty() and not (comp.name + " " + field.name).to_lower().contains(filter.text.to_lower()): continue
			visible_count += 1
			var item := tree.create_item(row)
			item.set_metadata(0, {"component": comp.iid, "script": comp.script, "field": field})
			item.set_text(0, field.name.capitalize())
			item.set_tooltip_text(0, field.name + " · " + type_string(field.type))
			if selected.get("component") == comp.iid and selected.get("field", {}).get("name") == field.name:
				item.select(0)
				selected = item.get_metadata(0)
			item.set_text(1, field.value.display)
			item.set_tooltip_text(1, type_string(field.type) + ": " + field.value.display)
			item.set_text(3, "" if field.writable else "Read only")
			for previous_comp in _previous.get("components", []):
				if previous_comp.iid == comp.iid:
					for previous_field in previous_comp.fields:
						if previous_field.name == field.name and not GECSExplorerCodec.equal(previous_field.value, field.value): item.set_text(3, "Changed")
			for draft in drafts:
				if draft.op == "set" and draft.component == comp.iid and draft.property == field.name:
					item.set_text(2, draft.value.display)
					item.set_text(3, "Draft" if GECSExplorerCodec.equal(draft.expected, field.value) else "Conflict")
					item.set_custom_color(2, UI.WARNING)
					item.set_custom_color(3, UI.WARNING if GECSExplorerCodec.equal(draft.expected, field.value) else UI.ERROR)
		row.visible = visible_count > 0 or (comp.fields.is_empty() and filter.text.is_empty())
	_render_relationships()
	for child in tree.get_children(true):
		if child is VScrollBar: child.set_deferred("value", scroll)
	_rendering = false
	if not selected.is_empty() and tree.get_selected() == null: _selected()
	_update_identity()
	var conflicts := false
	for draft in drafts:
		if draft.op == "set":
			for comp in snapshot.get("components", []):
				if comp.iid == draft.component:
					for field in comp.fields:
						if field.name == draft.property and not GECSExplorerCodec.equal(draft.expected, field.value): conflicts = true
	_conflict_actions.visible = conflicts
	_draft_card.visible = not drafts.is_empty()
	_draft_title.text = "%d staged change%s%s" % [drafts.size(), "" if drafts.size() == 1 else "s", " · conflict needs review" if conflicts else ""]
	if draft_list != null:
		draft_list.clear()
		for draft in drafts:
			var text := str(draft.op).capitalize() + " · " + str(draft.get("property", draft.get("script", ""))).get_file()
			if draft.op == "set": text = str(draft.property).capitalize() + "  →  " + str(draft.value.display)
			draft_list.add_item(text)
		draft_list.visible = drafts.size() > 1
		if drafts.size() == 1 and drafts[0].op == "set": _draft_title.text = "%s → %s" % [str(drafts[0].property).capitalize(), drafts[0].value.display]
	if model != null:
		var available: bool = model.connected and not model.script_breaked and ref.get("world") == model.world_id and ref.get("epoch") == model.epoch
		for button in _buttons:
			if button.text in ["Apply", "Apply to game", "Replace conflicting values"]: button.disabled = _busy or not available or drafts.is_empty()
		apply_step.disabled = _busy or not available or drafts.is_empty() or not model.step_state.get("paused", false)
	if selected.has("field") and drafts.is_empty() and proxy != null and _editor_card.visible:
		var focus := get_viewport().gui_get_focus_owner()
		var editing := focus != null and ((inspector != null and inspector.is_ancestor_of(focus)) or focus == fallback)
		if not editing and proxy.values.get(selected.field.name) != GECSExplorerCodec.decode(selected.field.value): _selected()
	if not pending_property_path.is_empty(): _focus_pending_property()
	_save_button.get_parent().visible = not drafts.is_empty() or selected.get("field", {}).get("writable", false)
	if feedback.text.begins_with("Loading") and not snapshot.is_empty(): feedback.text = "Select a property to edit or watch. Changes stay in the running game."

func _render_relationships() -> void:
	# Direction + owner + relationship ID keeps self-links and shared resource
	# IDs distinct, while preserving selection and native double-click tracking.
	var root := relationship_tree.get_root()
	if root == null: root = relationship_tree.create_item()
	var existing := {}
	for row in root.get_children(): existing[row.get_meta("relationship_id", "")] = row
	var outgoing: Array = snapshot.get("relationships", [])
	var incoming: Array = snapshot.get("incoming_relationships", [])
	var more := bool(snapshot.get("incoming_truncated", false))
	_relationship_count.text = "%d outgoing · %d%s incoming" % [outgoing.size(), incoming.size(), "+" if more else ""]
	_relationship_count.tooltip_text = "Incoming links are stored on their source entity. Showing the first 256 incoming links." if more else "Incoming links are stored on their source entity. Double-click a row to open the other entity."
	var entries: Array = []
	for relation in outgoing:
		var entry: Dictionary = relation.duplicate()
		entry["direction"] = "outgoing"
		entry["other"] = relation.get("target", {})
		entry["owner"] = ref
		entries.append(entry)
	for relation in incoming:
		var entry: Dictionary = relation.duplicate()
		entry["direction"] = "incoming"
		entry["other"] = relation.get("source", {})
		entry["owner"] = relation.get("source", {})
		entry["label"] = str(relation.get("source_label", "Entity"))
		entries.append(entry)
	relationship_tree.visible = not entries.is_empty()
	_relationships_empty.visible = entries.is_empty()
	var previous: TreeItem
	for entry in entries:
		var key := "%s:%s:%s" % [entry.direction, entry.owner.get("iid", 0), entry.iid]
		var row: TreeItem = existing.get(key)
		if row == null:
			row = relationship_tree.create_item(root)
			row.set_meta("relationship_id", key)
		existing.erase(key)
		if previous == null:
			if root.get_first_child() != row: row.move_before(root.get_first_child())
		elif row.get_prev() != previous: row.move_after(previous)
		previous = row
		var is_incoming: bool = entry.direction == "incoming"
		row.set_text(0, "← Incoming" if is_incoming else "→ Outgoing")
		row.set_custom_color(0, Color("97baff") if is_incoming else UI.ACCENT)
		row.set_text(1, entry.relation)
		row.set_text(2, entry.label)
		var current := str(snapshot.get("name", "This entity"))
		var help := "%s → %s · %s" % [entry.label if is_incoming else current, current if is_incoming else entry.label, entry.relation]
		if is_incoming:
			help += "\nStored on %s. Open that entity to edit or remove this link." % entry.label
			if not entry.get("source_enabled", true): help += "\nSource entity is disabled."
		for column in 3: row.set_tooltip_text(column, help)
		row.set_metadata(0, entry)
	for row in existing.values(): row.free()

func _relationship_context() -> Dictionary:
	var row := relationship_tree.get_selected()
	if row == null or not row.get_metadata(0) is Dictionary: return {}
	var entry: Dictionary = row.get_metadata(0)
	var is_incoming: bool = entry.get("direction") == "incoming"
	var actions := {}
	if not entry.get("other", {}).is_empty():
		actions["Open source entity" if is_incoming else "Open target entity"] = _open_relationship
		actions["Reveal source node" if is_incoming else "Reveal target node"] = func(): model.reveal(entry.other)
	if not is_incoming:
		actions["Stage removal"] = func(): _stage({"op": "remove_relationship", "relationship": entry.iid})
	return actions

func _resize_graph_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_graph_resizing = event.pressed
	elif event is InputEventMouseMotion and _graph_resizing:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_graph_resizing = false
			return
		_graph_height = clampf(_graph_height + event.relative.y / UI.scale(), 200.0, 1400.0)
		graph_panel.custom_minimum_size.y = UI.px(_graph_height)

func _open_graph_window() -> void:
	if is_instance_valid(_graph_window):
		_dock_graph()
		return
	_graph_window = Window.new()
	_graph_window.visible = false
	_graph_window.title = "Relationships · " + str(snapshot.get("name", name))
	_graph_window.force_native = true
	_graph_window.transient = false
	_graph_window.exclusive = false
	_graph_window.theme = UI.make_theme()
	_graph_window.size = Vector2i(UI.px(1000), UI.px(700))
	_graph_window.min_size = Vector2i(UI.px(500), UI.px(360))
	_graph_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	add_child(_graph_window)
	_graph_card.reparent(_graph_window)
	_graph_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graph_panel.custom_minimum_size.y = UI.px(200)
	_graph_resize_handle.hide()
	_graph_popout.text = "Dock graph"
	_graph_window.close_requested.connect(_dock_graph)
	_graph_window.show()

func _dock_graph() -> void:
	if not is_instance_valid(_graph_window): return
	var window := _graph_window
	_graph_window = null
	_graph_card.reparent(_sidebar)
	_graph_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	graph_panel.custom_minimum_size.y = UI.px(_graph_height)
	_graph_resize_handle.show()
	_graph_popout.text = "Open in window"
	window.hide()
	window.queue_free()

func _selected() -> void:
	if _rendering: return
	_editor_card.show()
	if _chart_focus: _chart_focus.text = "Focus"
	var item := tree.get_selected()
	selected = item.get_metadata(0) if item and item.get_metadata(0) is Dictionary else {}
	_property_actions.visible = not selected.is_empty()
	var has_field := selected.has("field")
	_save_button.get_parent().visible = not drafts.is_empty() or selected.get("field", {}).get("writable", false)
	_watch_button.disabled = not has_field or not selected.field.type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I]
	_watch_button.tooltip_text = "Chart numeric values, vector channels, booleans, or enum transitions."
	if inspector != null: inspector.visible = has_field
	if fallback != null: fallback.visible = has_field
	if not has_field:
		_property_title.text = "Component actions" if selected.has("component") else "Relationship" if selected.has("relationship") else "Choose a property"
		_property_help.text = "Select a property to edit its value. Use More for structural actions." if not selected.is_empty() else "Click a value in the component table to edit or watch it."
		return
	_property_title.text = str(selected.field.name).capitalize()
	_property_help.text = selected.script.get_file().get_basename() + " / " + selected.field.name + " · " + type_string(selected.field.type)
	var field: Dictionary = selected.field.duplicate(true)
	for draft in drafts:
		if draft.op == "set" and draft.component == selected.component and draft.property == field.name: field.value = draft.value
	proxy.configure([field])
	if inspector != null: inspector.call("edit", proxy)
	if fallback != null: fallback.text = var_to_str(GECSExplorerCodec.decode(field.value))

func _stage_expression(text: String) -> void:
	if not selected.has("field"): return
	var expression := Expression.new()
	if expression.parse(text) != OK:
		feedback.text = expression.get_error_text()
		return
	var value: Variant = expression.execute([], null, false)
	if expression.has_execute_failed():
		feedback.text = expression.get_error_text()
		return
	_stage_property(selected.field.name, value)

func _stage_property(property: String, value: Variant) -> void:
	if not selected.has("field") or property != selected.field.name or not selected.field.get("writable", false): return
	_stage({"op": "set", "component": selected.component, "property": property, "expected": selected.field.value, "value": GECSExplorerCodec.encode(value)})

func _stage(operation: Dictionary) -> void:
	if _busy:
		feedback.text = "Waiting for the applied values from the game"
		return
	if operation.op == "set":
		for existing in drafts:
			if existing.op == "set" and existing.component == operation.component and existing.property == operation.property:
				existing.value = operation.value
				_render()
				return
	drafts.append(operation)
	feedback.text = "Change staged. Apply to game saves it to the running session."
	_render()

func _refresh_bases() -> void:
	for draft in drafts:
		if draft.op == "set":
			for comp in snapshot.get("components", []):
				if comp.iid == draft.component:
					for field in comp.fields:
						if field.name == draft.property: draft.expected = field.value.duplicate(true)
	_render()

func _apply(step: bool, force := false) -> void:
	if _busy: return
	if drafts.is_empty():
		feedback.text = "No staged edits"
		return
	var args := {"entity": ref, "operations": drafts.duplicate(true), "force": force}
	if step: args["step"] = model.step_state.get("preferred_kind", 2)
	_busy = true
	if model.request("apply", args, {"key": _watch_key}) == 0:
		_busy = false
		feedback.text = "No connected world"
	_render()

func _toggle_graph(enabled: bool) -> void:
	if not enabled: _dock_graph()
	graph_panel.visible = enabled
	_graph_card.visible = enabled
	if enabled:
		if graph_id == 0:
			graph_id = model.allocate_graph()
			graph_panel.graph_id = graph_id
		graph_panel.watch_ids = [ref.iid]
		model.sender.call("gecs:graph_watch", [graph_id, [ref.iid], 0])
	else:
		model.sender.call("gecs:graph_close", [graph_id])

func add_chart(property: Dictionary) -> void:
	if not property.has("field") or not property.field.type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I]: return
	for existing in chart_properties:
		if existing.component == property.component and existing.field.name == property.field.name:
			chart_toggle.button_pressed = true
			return
	if chart_properties.size() >= 16:
		feedback.text = "Up to 16 charts per entity. Remove a chart before adding another."
		return
	chart_properties.append(property.duplicate(true))
	_rebuild_charts()
	chart_toggle.button_pressed = true
	_update_chart()

func _clear_charts() -> void:
	chart_properties.clear()
	chart_property = {}
	_rebuild_charts()
	chart_toggle.button_pressed = false

func _rebuild_charts() -> void:
	for entry in _extra_charts:
		entry.node.get_parent().remove_child(entry.node)
		entry.node.queue_free()
	_extra_charts.clear()
	chart.hide()
	for property in chart_properties:
		var body := VBoxContainer.new()
		_chart_body.add_child(body)
		var heading := HBoxContainer.new()
		body.add_child(heading)
		var title := UI.label(heading, property.script.get_file().get_basename() + " / " + property.field.name, 12, UI.ACCENT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.button(heading, "×", func():
			chart_properties.erase(property)
			_rebuild_charts()
			_update_chart()
			if chart_properties.is_empty(): chart_toggle.button_pressed = false
		)
		var plot := GECSExplorerChart.new()
		body.add_child(plot)
		_extra_charts.append({"node": body, "plot": plot, "property": property})
	chart_property = chart_properties[0] if not chart_properties.is_empty() else {}

func _update_chart() -> void:
	# Single-chart compatibility for older saved layouts.
	if chart_properties.is_empty() and chart_property.has("field"): add_chart(chart_property)
	chart.visible = false
	for entry in _extra_charts:
		var property: Dictionary = entry.property
		entry.plot.state_transitions = property.field.type == TYPE_BOOL or property.field.get("hint", 0) in [PROPERTY_HINT_ENUM, PROPERTY_HINT_FLAGS]
		entry.plot.set_samples(model.series.get(_watch_key, []), property.component, property.field.name)

func _open_relationship() -> void:
	var row := relationship_tree.get_selected()
	if row == null or not row.get_metadata(0) is Dictionary: return
	var target: Dictionary = row.get_metadata(0).get("other", {})
	if target.is_empty():
		feedback.text = "This relationship targets a component, script, or wildcard rather than a live entity."
		return
	if model.connected and target.get("world") == model.world_id and target.get("epoch") == model.epoch: open_entity.emit(target)

func _property_context() -> Dictionary:
	_selected()
	var actions := {}
	if selected.has("field"):
		actions["Add property chart"] = func(): add_chart(selected)
		actions["Copy live value"] = func(): DisplayServer.clipboard_set(selected.field.value.display)
	if selected.has("component"):
		actions["Open component script"] = func(): _open_script(selected.script)
		actions["Stage component removal"] = func(): _stage({"op": "remove_component", "component": selected.component})
	return actions

func _focus_pending_property() -> void:
	var split := pending_property_path.rfind(":")
	if split < 0: return
	for component in snapshot.get("components", []):
		if component.script != pending_property_path.left(split): continue
		for field in component.fields:
			if field.name == pending_property_path.substr(split + 1):
				selected = {"component": component.iid, "script": component.script, "field": field}
				pending_property_path = ""
				_render()
				_selected()
				return

func _open_script(path: String) -> void:
	if not path.is_empty() and Engine.is_editor_hint():
		var script := load(path) as Script
		if script: EditorInterface.edit_script(script)


func release() -> void:
	if _released or model == null: return
	_released = true
	model.unwatch(_watch_key)
	if graph_id != 0 and model.sender.is_valid(): model.sender.call("gecs:graph_close", [graph_id])
	model.graph_ids.erase(graph_id)

func _exit_tree() -> void:
	if is_queued_for_deletion(): release()

func _connect_watch() -> void:
	model.watch(ref, _watch_key)
	model.request("inspect", {"entity": ref}, {"key": _watch_key})

func _graph_activated(entity: Dictionary) -> void:
	if not model.connected or ref.get("world") != model.world_id or ref.get("epoch") != model.epoch: return
	if entity.get("instance_id", 0) != 0 and entity.get("id", 0) != 0:
		open_entity.emit({"world": ref.world, "epoch": ref.epoch, "iid": entity.instance_id, "id": entity.id})

func layout_definition() -> Dictionary:
	return {"relationship_split": _data_split.split_offset, "graph_height": _graph_height, "charts": chart_properties.map(func(p): return {"script": p.script, "property": p.field.name}), "chart_component": chart_property.get("script", ""), "chart_property": chart_property.get("field", {}).get("name", ""), "chart_visible": chart_toggle.button_pressed, "relationships": graph_toggle.button_pressed, "split": _split.split_offset, "advanced": advanced.button_pressed, "filter": filter.text}

func _restore_layout() -> void:
	if pending_layout.is_empty() or snapshot.is_empty(): return
	var layout := pending_layout
	pending_layout = {}
	var definitions: Array = layout.get("charts", [{"script": layout.get("chart_component", ""), "property": layout.get("chart_property", "")}])
	for definition in definitions.slice(0, 16):
		for component in snapshot.get("components", []):
			if component.script != definition.get("script", ""): continue
			for field in component.fields:
				if field.name == definition.get("property", ""): add_chart({"component": component.iid, "script": component.script, "field": field})
	advanced.button_pressed = layout.get("advanced", false)
	filter.text = layout.get("filter", "")
	_split.split_offset = int(layout.get("split", 0))
	_data_split.split_offset = int(layout.get("relationship_split", 0))
	_graph_height = clampf(float(layout.get("graph_height", 360.0)), 200.0, 1400.0)
	graph_panel.custom_minimum_size.y = UI.px(_graph_height)
	graph_toggle.button_pressed = layout.get("relationships", false)
	chart_toggle.button_pressed = layout.get("chart_visible", false)
