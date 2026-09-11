@tool
extends ScrollContainer
## Dashboard preferences are local; freezing this view never pauses ECS.
const UI = preload("res://addons/gecs/debug/explorer/gecs_explorer_ui.gd")
const METRICS := {"entities": "Entities", "enabled": "Enabled entities", "components": "Component instances", "relationships": "Relationships", "archetypes": "Archetypes", "system_ms": "System cost · ms", "active_systems": "Active systems", "cached_queries": "Cached queries", "observers": "Observers"}
const SAMPLE_LIMIT := 240
signal query_requested(kind: String, script: String)
signal systems_requested
signal refresh_requested
signal preferences_changed
var metrics: Dictionary = {}
var details: Dictionary = {}
var history: Array = []
var latest: Dictionary = {}
var component_tree: Tree
var relationship_tree: Tree
var system_tree: Tree
var interval_ms := 1000
var window_seconds := 120
var row_limit := 12
var frozen := false
var _metrics_grid: GridContainer
var _charts_grid: GridContainer
var _tables_grid: GridContainer
var _entity_chart: GECSExplorerChart
var _time_chart: GECSExplorerChart
var _note: Label
var _structure: Label
var _state := "Waiting for the world"
var _deltas: Dictionary = {}
var _pickers: Array[OptionButton] = []
var _readouts: Array[Label] = []
var _ranges: Array[Label] = []
var _chart_keys: Array = ["entities", "system_ms"]
var _sorts: Dictionary = {}
var _table_help: Dictionary = {}
var _refresh_button: Button
var _freeze_button: Button
var _options: MenuButton
var _applying_options := false

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)
	var heading := UI.heading(body, "World overview", "Membership, composition and system cost at a glance.")
	_refresh_button = UI.button(heading, "↻", func(): refresh_requested.emit(), false, "Refresh this dashboard once, including while its view is frozen.")
	_freeze_button = UI.button(heading, "Freeze view", func(): pass, false, "Hold dashboard values and charts. The game and ECS keep running.")
	_freeze_button.toggle_mode = true
	_freeze_button.toggled.connect(func(value: bool):
		frozen = value
		_freeze_button.text = "View frozen" if value else "Freeze view"
		_update_note()
	)
	_options = MenuButton.new()
	_options.text = "Options ▾"
	_options.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(_options)
	_build_options()
	_metrics_grid = GridContainer.new()
	_metrics_grid.columns = 4
	body.add_child(_metrics_grid)
	for key in ["Entities", "Components", "Relationships", "Systems"]:
		var card := UI.card(_metrics_grid)
		UI.label(card, key.to_upper(), 11, UI.MUTED)
		var values := HBoxContainer.new()
		card.add_child(values)
		metrics[key] = UI.label(values, "—", 28, UI.ACCENT)
		metrics[key].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_deltas[key] = UI.label(values, "", 12, UI.MUTED)
		_deltas[key].tooltip_text = "Net change since the first sample in the selected history window."
		details[key] = UI.hint(card, "Waiting for data")
	_structure = UI.hint(body, "Start a scene to see its ECS world. Open an entity from the browser to investigate.")
	_charts_grid = GridContainer.new()
	_charts_grid.columns = 2
	body.add_child(_charts_grid)
	for index in 2:
		var card := UI.card(_charts_grid)
		var header := HBoxContainer.new()
		card.add_child(header)
		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for key in METRICS:
			picker.add_item(METRICS[key])
			picker.set_item_metadata(picker.item_count - 1, key)
		picker.select(0 if index == 0 else 5)
		picker.item_selected.connect(func(item: int):
			_chart_keys[index] = picker.get_item_metadata(item)
			_render_charts()
			_changed()
		)
		header.add_child(picker)
		_pickers.append(picker)
		_readouts.append(UI.label(header, "—", 22, UI.ACCENT if index == 0 else Color("97baff")))
		var chart := GECSExplorerChart.new()
		card.add_child(chart)
		chart.custom_minimum_size.y = UI.px(130)
		chart.axis_width = 54.0
		chart.minimum_axis_value = 0.0
		chart.show_hover = true
		chart.right_label = "latest"
		chart.line_color = UI.ACCENT if index == 0 else Color("97baff")
		if index == 0: _entity_chart = chart
		else: _time_chart = chart
		_ranges.append(UI.hint(card, "Waiting for samples"))
	_tables_grid = GridContainer.new()
	_tables_grid.columns = 3
	body.add_child(_tables_grid)
	component_tree = _table("Component types", ["Component", "Instances"])
	relationship_tree = _table("Relationship types", ["Relation", "Links"])
	system_tree = _table("System timings", ["System", "Last ms", "Avg ms"])
	component_tree.item_activated.connect(func(): _query(component_tree, "component"))
	relationship_tree.item_activated.connect(func(): _query(relationship_tree, "relationship"))
	system_tree.item_activated.connect(func(): systems_requested.emit())
	for tree in [component_tree, relationship_tree]:
		UI.context_menu(tree, func():
			return {"Find matching entities": func(): _query(tree, "component" if tree == component_tree else "relationship"), "Copy displayed rows": func(): _copy_rows(tree)}
		)
	UI.context_menu(system_tree, func(): return {"Open Systems": func(): systems_requested.emit(), "Copy displayed rows": func(): _copy_rows(system_tree)})
	_note = UI.hint(body, "Waiting for the world · dashboard refreshes only while visible.")
	resized.connect(_fit)
	_fit.call_deferred()

func _build_options() -> void:
	var popup := _options.get_popup()
	popup.add_check_item("Show charts", 1)
	popup.set_item_checked(0, true)
	for spec in [["Refresh rate", "Rate", ["Twice per second", "Every second", "Every 2 seconds"]], ["History window", "History", ["30 seconds", "1 minute", "2 minutes"]], ["Summary rows", "Rows", ["Top 12", "Top 24", "Top 48"]]]:
		var menu := PopupMenu.new()
		menu.name = spec[1]
		popup.add_child(menu)
		for label in spec[2]: menu.add_radio_check_item(label)
		menu.id_pressed.connect(func(index: int):
			match menu.name:
				"Rate": interval_ms = [500, 1000, 2000][index]
				"History": window_seconds = [30, 60, 120][index]
				"Rows": row_limit = [12, 24, 48][index]
			_trim_history()
			_render_charts()
			_render_tables()
			_update_note()
			_sync_options()
			_changed()
		)
		popup.add_submenu_item(spec[0], menu.name, 10 + popup.item_count)
	popup.add_separator()
	popup.add_item("Clear chart history", 2)
	popup.add_item("Copy overview as JSON", 3)
	popup.add_item("Copy chart samples as CSV", 4)
	popup.add_separator()
	popup.add_item("Open Systems", 5)
	popup.id_pressed.connect(func(id: int):
		match id:
			1:
				_charts_grid.visible = not _charts_grid.visible
				popup.set_item_checked(0, _charts_grid.visible)
				_changed()
			2:
				history.clear()
				_render_charts()
			3: DisplayServer.clipboard_set(JSON.stringify({"format": "gecs-world-overview", "version": 1, "summary": latest, "samples": _visible_history()}, "  "))
			4: DisplayServer.clipboard_set(samples_csv())
			5: systems_requested.emit()
	)
	_sync_options()

func _sync_options() -> void:
	for name in ["Rate", "History", "Rows"]:
		var menu: PopupMenu = _options.get_popup().get_node(name)
		var selected: int = [500, 1000, 2000].find(interval_ms) if name == "Rate" else [30, 60, 120].find(window_seconds) if name == "History" else [12, 24, 48].find(row_limit)
		for i in menu.item_count: menu.set_item_checked(i, i == selected)

func _table(title: String, columns: Array) -> Tree:
	var card := UI.card(_tables_grid)
	card.get_parent().clip_contents = true
	UI.label(card, title, 16)
	var help := UI.hint(card, "Waiting for data")
	help.custom_minimum_size.y = UI.px(32)
	var tree := Tree.new()
	tree.columns = columns.size()
	tree.hide_root = true
	tree.column_titles_visible = true
	tree.clip_contents = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(UI.px(220), UI.px(180))
	for i in columns.size():
		tree.set_column_title(i, columns[i])
		if i > 0:
			tree.set_column_expand(i, false)
			tree.set_column_custom_minimum_width(i, UI.px(68))
	tree.set_meta("titles", columns)
	_sorts[tree] = {"column": 1, "descending": true}
	tree.column_title_clicked.connect(func(column: int):
		var sort: Dictionary = _sorts[tree]
		sort.descending = not sort.descending if sort.column == column else column != 0
		sort.column = column
		_render_tables()
	)
	card.add_child(tree)
	_table_help[tree] = help
	return tree

func _fit() -> void:
	_metrics_grid.columns = 4 if size.x >= UI.px(650) else 2
	_charts_grid.columns = 2 if size.x >= UI.px(660) else 1
	_tables_grid.columns = 3 if size.x >= UI.px(1050) else 2 if size.x >= UI.px(700) else 1

func apply(data: Dictionary, force := false) -> void:
	if frozen and not force: return
	if not history.is_empty() and float(data.time) - float(history.back().time) > maxf(2500.0, interval_ms * 2.5): history.clear()
	latest = data.duplicate(true)
	var sample := {"time": data.time}
	for key in METRICS: sample[key] = data.get(key)
	sample.systems = data.systems
	history.append(sample)
	_trim_history()
	for key in metrics: metrics[key].text = str(data[key.to_lower()])
	details.Entities.text = "%d enabled · %d disabled" % [data.enabled, data.entities - data.enabled]
	details.Components.text = "%d types in use" % data.component_types
	details.Relationships.text = "%d relation types" % data.relationship_types
	details.Systems.text = "%d active · %d observers" % [data.active_systems, data.observers]
	_structure.text = "%d populated archetypes   ·   %d cached queries   ·   All entities in this world" % [data.archetypes, data.cached_queries]
	_render_charts()
	_render_tables()
	_update_note()

func _trim_history() -> void:
	if history.is_empty(): return
	var cutoff := float(history.back().time) - 120000.0
	while history.size() > 1 and (history.size() > SAMPLE_LIMIT or float(history.front().time) <= cutoff): history.pop_front()

func _visible_history() -> Array:
	if history.is_empty(): return []
	var cutoff := float(history.back().time) - window_seconds * 1000.0
	return history.filter(func(sample): return float(sample.time) > cutoff)

func _render_charts() -> void:
	if _entity_chart == null: return
	var samples := _visible_history()
	for key in _deltas:
		var delta := int(samples.back().get(key.to_lower(), 0)) - int(samples.front().get(key.to_lower(), 0)) if samples.size() > 1 else 0
		_deltas[key].text = "%+d" % delta if delta != 0 else ""
	for index in 2:
		var key: String = _chart_keys[index]
		var chart: GECSExplorerChart = [_entity_chart, _time_chart][index]
		chart.values = samples.map(func(sample): return sample.get(key))
		chart.sample_times = samples.map(func(sample): return sample.time)
		chart.duration = (float(samples.back().time) - float(samples.front().time)) / 1000.0 if samples.size() > 1 else 0.0
		chart.constant_padding = 0.001 if key == "system_ms" else 1.0
		chart.axis_decimals = 3 if key == "system_ms" else 1
		chart.caption = "Latest system runs, not frame time" if key == "system_ms" else "World total · hover for sample values"
		chart.empty_text = "No measured system runs yet" if key == "system_ms" else "Refresh to collect samples"
		chart.queue_redraw()
		_readouts[index].text = _format(latest.get(key), key)
		var measured: Array = chart.values.filter(func(value): return value != null)
		_ranges[index].text = "Min %s   ·   Max %s   ·   %d samples" % [_format(measured.min(), key), _format(measured.max(), key), measured.size()] if not measured.is_empty() else "No samples in this window"

func _format(value: Variant, key: String) -> String:
	if value == null: return "—"
	return "%.3f ms" % float(value) if key == "system_ms" else str(int(value))

func _render_tables() -> void:
	if latest.is_empty(): return
	for tree in [component_tree, relationship_tree, system_tree]:
		var timing: bool = tree == system_tree
		var key := "system_rows" if timing else "component_rows" if tree == component_tree else "relationship_rows"
		var total: int = latest["systems" if timing else "component_types" if tree == component_tree else "relationship_types"]
		var rows: Array = latest.get(key, []).slice(0, row_limit).duplicate()
		var sort: Dictionary = _sorts[tree]
		var column := "name" if sort.column == 0 else "count" if not timing else "last_ms" if sort.column == 1 else "avg_ms"
		rows.sort_custom(func(a, b):
			if a[column] == b[column]: return str(a.name) < str(b.name)
			return a[column] > b[column] if sort.descending else a[column] < b[column]
		)
		var titles: Array = tree.get_meta("titles")
		for i in titles.size(): tree.set_column_title(i, titles[i] + (" ▼" if sort.descending else " ▲") if i == sort.column else titles[i])
		_table_help[tree].text = "%d of %d · double-click %s" % [rows.size(), total, "for Systems" if timing else "to query"]
		_table_help[tree].tooltip_text = "Sort the displayed top %d by clicking a column. Change the row limit in Options." % row_limit
		_fill(tree, rows, timing)

func _row_key(entry: Dictionary) -> String:
	return str(entry.iid) if entry.has("iid") else str(entry.script) if entry.get("script", "") != "" else str(entry.get("name", ""))

func _fill(tree: Tree, rows: Array, timings := false) -> void:
	var scroll_values := {}
	for child in tree.get_children(true):
		if child is ScrollBar: scroll_values[child] = child.value
	var root := tree.get_root()
	if root == null: root = tree.create_item()
	var old := {}
	var child := root.get_first_child()
	while child != null:
		var next := child.get_next()
		if child.get_metadata(0) is Dictionary: old[_row_key(child.get_metadata(0))] = child
		else: child.free()
		child = next
	var previous: TreeItem
	for entry in rows:
		var key := _row_key(entry)
		var row: TreeItem = old.get(key)
		if row == null: row = tree.create_item(root)
		old.erase(key)
		if previous == null:
			if root.get_first_child() != row: row.move_before(root.get_first_child())
		elif row.get_prev() != previous: row.move_after(previous)
		previous = row
		row.set_text(0, entry.name + (" · off" if timings and not entry.active else ""))
		row.set_tooltip_text(0, row.get_text(0))
		row.set_metadata(0, entry)
		if timings:
			row.set_text(1, "%.3f" % entry.last_ms if entry.measured else "—")
			row.set_text(2, "%.3f" % entry.avg_ms if entry.measured else "—")
		else: row.set_text(1, str(entry.count))
	for row in old.values(): row.free()
	if rows.is_empty():
		var empty := tree.create_item(root)
		empty.set_text(0, "No systems" if timings else "None in this world")
		empty.set_selectable(0, false)
	for bar in scroll_values: bar.set_deferred("value", scroll_values[bar])

func _query(tree: Tree, kind: String) -> void:
	var row := tree.get_selected()
	if row == null or not row.get_metadata(0) is Dictionary: return
	var path := str(row.get_metadata(0).get("script", ""))
	if path != "": query_requested.emit(kind, path)

func _copy_rows(tree: Tree) -> void:
	var lines: Array[String] = ["\t".join(tree.get_meta("titles"))]
	var row := tree.get_root().get_first_child() if tree.get_root() else null
	while row != null:
		var cells: Array[String] = []
		for i in tree.columns: cells.append(row.get_text(i).replace("\t", " ").replace("\n", " "))
		lines.append("\t".join(cells))
		row = row.get_next()
	DisplayServer.clipboard_set("\n".join(lines))

func samples_csv() -> String:
	var lines: Array[String] = ["time_ms," + ",".join(METRICS.keys())]
	for sample in _visible_history():
		var cells: Array[String] = [str(sample.time)]
		for key in METRICS: cells.append(str(sample[key]) if sample.get(key) != null else "")
		lines.append(",".join(cells))
	return "\n".join(lines)

func preferences() -> Dictionary:
	return {"interval_ms": interval_ms, "window_seconds": window_seconds, "row_limit": row_limit, "charts_visible": _charts_grid.visible, "chart_keys": _chart_keys.duplicate()}

func load_preferences(data: Dictionary) -> void:
	_applying_options = true
	interval_ms = int(data.get("interval_ms", 1000)) if data.get("interval_ms", 1000) in [500, 1000, 2000] else 1000
	window_seconds = int(data.get("window_seconds", 120)) if data.get("window_seconds", 120) in [30, 60, 120] else 120
	row_limit = int(data.get("row_limit", 12)) if data.get("row_limit", 12) in [12, 24, 48] else 12
	_charts_grid.visible = data.get("charts_visible", true) != false
	_options.get_popup().set_item_checked(0, _charts_grid.visible)
	var keys: Variant = data.get("chart_keys", [])
	if keys is Array and keys.size() == 2:
		for i in 2:
			if keys[i] is String and METRICS.has(keys[i]):
				_chart_keys[i] = keys[i]
				_pickers[i].select(METRICS.keys().find(keys[i]))
	_sync_options()
	_trim_history()
	_render_charts()
	_render_tables()
	_update_note()
	_applying_options = false

func _changed() -> void:
	if not _applying_options: preferences_changed.emit()

func _update_note() -> void:
	if _note == null: return
	var state := "View frozen · ECS unchanged" if frozen else _state
	var suffix := " · displayed data is frozen" if _state in ["Session ended", "Godot debugger break"] else ""
	_note.text = "%s%s · %.1fs refresh while visible · %ds history" % [state, suffix, interval_ms / 1000.0, window_seconds]
	_note.tooltip_text = "Collected in %.2f ms. System timings are cached latest runs and may come from different frames. Sampling gaps start a new chart segment." % float(latest.get("collection_ms", 0.0))

func set_state(state: String, clear := false) -> void:
	_state = state
	if _note == null: return
	_refresh_button.disabled = state not in ["Live", "ECS paused"]
	if clear:
		latest.clear()
		history.clear()
		for metric in metrics.values(): metric.text = "—"
		for detail in details.values(): detail.text = "Waiting for data"
		_render_charts()
		for tree in [component_tree, relationship_tree, system_tree]: tree.clear()
		_structure.text = "Waiting for this world's first sample."
	_update_note()
