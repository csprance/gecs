@tool
class_name GECSEditorDebuggerTab
extends Control

@onready var query_builder_check_box: CheckBox = %QueryBuilderCheckBox
@onready var entities_filter_line_edit: LineEdit = %EntitiesQueryLineEdit
@onready var systems_filter_line_edit: LineEdit = %SystemsQueryLineEdit
@onready var collapse_all_btn: Button = %CollapseAllBtn
@onready var expand_all_btn: Button = %ExpandAllBtn
@onready var systems_collapse_all_btn: Button = %SystemsCollapseAllBtn
@onready var systems_expand_all_btn: Button = %SystemsExpandAllBtn
@onready var systems_reset_metrics_btn: Button = %SystemsResetMetricsBtn
@onready var pop_out_btn: Button = %PopOutBtn
@onready var poll_rate_spin_box: SpinBox = %PollRateSpinBox
# Capture-category toggles — each re-sends the subscription so the game only
# produces the categories currently being viewed.
@onready var lifecycle_check_box: CheckBox = %LifecycleCheckBox
@onready var prop_changes_check_box: CheckBox = %PropChangesCheckBox
@onready var metrics_check_box: CheckBox = %MetricsCheckBox
@onready var metrics_hz_spin_box: SpinBox = %MetricsHzSpinBox

var ecs_data: Dictionary = {}
var default_system := {"path": "", "active": true, "metrics": {}, "group": ""}
var default_entity := {"path": "", "active": true, "components": {}, "relationships": {}}
var timer = 5
var active := false
var _pending_components: Dictionary = {}  # ent_id -> Array[Dictionary] of pending component data
var _popup_window: Window = null
var _debugger_session: EditorDebuggerSession = null

@onready var system_tree: Tree = %SystemsTree
@onready var entities_tree: Tree = %EntitiesTree
@onready var entity_status_bar: TextEdit = %EntityStatusBar
@onready var systems_status_bar: TextEdit = %SystemsStatusBar
@onready var debug_mode_overlay: Panel = %DebugModeOverlay

# Sorting state
var _system_sort_column: int = -1  # -1 means no sorting
var _system_sort_ascending: bool = true
var _entity_sort_column: int = -1  # -1 means no sorting
var _entity_sort_ascending: bool = true

# Pinned items
var _pinned_entities: Dictionary = {}  # entity_id -> bool
var _pinned_systems: Dictionary = {}  # system_id -> bool

# Debug polling for live component data updates
var _poll_elapsed: float = 0.0

# Icon constants (using Unicode characters)
const ICON_ENTITY = "📦"  # Entity icon
const ICON_COMPONENT = "🔧"  # Component icon
const ICON_FLAG = "🚩"  # Flag component (no properties)
const ICON_RELATIONSHIP = "🔗"  # Relationship icon
const ICON_PIN = "📌"  # Pinned item icon

# ---- Manual column-resize state (Godot Tree has no native drag-to-resize) ----
const _RESIZE_GRAB_PX := 6.0
var _resizing_tree: Tree = null
var _resize_column: int = -1
var _resize_start_x: float = 0.0
var _resize_start_width: int = 0

# ---- Ad-hoc query mode (entities filter box) ----
## When true, the entities filter box is a QueryBuilder expression run in the game
## on Enter, rather than a client-side text filter.
var _query_mode: bool = false
## True while a query result is filtering the tree (distinct from an empty query).
var _query_active: bool = false
## Set of matching entity instance ids from the last query (id -> true).
var _query_result_ids: Dictionary = {}
## Transient query status (match count or error) appended to the entity status bar.
var _query_status_text: String = ""


func _ready() -> void:
	_match_theme_to_editor_luminance()
	_update_debug_mode_overlay()
	if system_tree:
		# Eight columns: name, group, current time, min, max, avg, status, order
		system_tree.columns = 8
		system_tree.set_column_expand(0, true)  # Name column expands
		system_tree.set_column_expand(1, false)  # Group column resizable
		system_tree.set_column_expand(2, false)  # Time column resizable
		system_tree.set_column_expand(3, false)  # Min column resizable
		system_tree.set_column_expand(4, false)  # Max column resizable
		system_tree.set_column_expand(5, false)  # Avg column resizable
		system_tree.set_column_expand(6, false)  # Status column resizable
		system_tree.set_column_expand(7, false)  # Order column resizable

		# Set column widths
		system_tree.set_column_custom_minimum_width(1, 100)  # Group: 100px min
		system_tree.set_column_custom_minimum_width(2, 90)  # Time: 90px min
		system_tree.set_column_custom_minimum_width(3, 90)  # Min: 90px min
		system_tree.set_column_custom_minimum_width(4, 90)  # Max: 90px min
		system_tree.set_column_custom_minimum_width(5, 90)  # Avg: 90px min
		system_tree.set_column_custom_minimum_width(6, 100)  # Status: 100px min
		system_tree.set_column_custom_minimum_width(7, 60)  # Order: 60px min

		# Enable column resizing (clip content allows manual resizing)
		system_tree.set_column_clip_content(0, true)
		system_tree.set_column_clip_content(1, true)
		system_tree.set_column_clip_content(2, true)
		system_tree.set_column_clip_content(3, true)
		system_tree.set_column_clip_content(4, true)
		system_tree.set_column_clip_content(5, true)
		system_tree.set_column_clip_content(6, true)
		system_tree.set_column_clip_content(7, true)

		# Set column titles (clickable for sorting)
		system_tree.set_column_title(0, "Name")
		system_tree.set_column_title(1, "Group")
		system_tree.set_column_title(2, "Time (ms)")
		system_tree.set_column_title(3, "Min (ms)")
		system_tree.set_column_title(4, "Max (ms)")
		system_tree.set_column_title(5, "Avg (ms)")
		system_tree.set_column_title(6, "Status")
		system_tree.set_column_title(7, "Order")
		system_tree.set_column_titles_visible(true)

		# Create root item
		if system_tree.get_root() == null:
			system_tree.create_item()
	if entities_tree:
		# Four columns: name, components count, relationships count, nodes count
		entities_tree.columns = 4
		entities_tree.set_column_expand(0, true)  # Name column expands
		entities_tree.set_column_expand(1, false)  # Components count resizable
		entities_tree.set_column_expand(2, false)  # Relationships count resizable
		entities_tree.set_column_expand(3, false)  # Nodes count resizable

		# Set column widths
		entities_tree.set_column_custom_minimum_width(1, 80)  # Components: 80px min
		entities_tree.set_column_custom_minimum_width(2, 80)  # Relationships: 80px min
		entities_tree.set_column_custom_minimum_width(3, 80)  # Nodes: 80px min

		# Enable column resizing (clip content allows manual resizing)
		entities_tree.set_column_clip_content(0, true)
		entities_tree.set_column_clip_content(1, true)
		entities_tree.set_column_clip_content(2, true)
		entities_tree.set_column_clip_content(3, true)

		# Set column titles
		entities_tree.set_column_title(0, "Entity")
		entities_tree.set_column_title(1, "Comps")
		entities_tree.set_column_title(2, "Rels")
		entities_tree.set_column_title(3, "Nodes")
		entities_tree.set_column_titles_visible(true)

		# Create root item
		if entities_tree.get_root() == null:
			entities_tree.create_item()
		# Polling & pinning removed; tree updates only via incoming messages
	if (
		entities_filter_line_edit
		and not entities_filter_line_edit.text_changed.is_connected(_on_entities_filter_changed)
	):
		entities_filter_line_edit.text_changed.connect(_on_entities_filter_changed)
	if (
		systems_filter_line_edit
		and not systems_filter_line_edit.text_changed.is_connected(_on_systems_filter_changed)
	):
		systems_filter_line_edit.text_changed.connect(_on_systems_filter_changed)
	if collapse_all_btn and not collapse_all_btn.pressed.is_connected(_on_collapse_all_pressed):
		collapse_all_btn.pressed.connect(_on_collapse_all_pressed)
	if expand_all_btn and not expand_all_btn.pressed.is_connected(_on_expand_all_pressed):
		expand_all_btn.pressed.connect(_on_expand_all_pressed)
	if (
		systems_collapse_all_btn
		and not systems_collapse_all_btn.pressed.is_connected(_on_systems_collapse_all_pressed)
	):
		systems_collapse_all_btn.pressed.connect(_on_systems_collapse_all_pressed)
	if (
		systems_expand_all_btn
		and not systems_expand_all_btn.pressed.is_connected(_on_systems_expand_all_pressed)
	):
		systems_expand_all_btn.pressed.connect(_on_systems_expand_all_pressed)
	if (
		systems_reset_metrics_btn
		and not systems_reset_metrics_btn.pressed.is_connected(_on_systems_reset_metrics_pressed)
	):
		systems_reset_metrics_btn.pressed.connect(_on_systems_reset_metrics_pressed)
	if pop_out_btn and not pop_out_btn.pressed.is_connected(_on_pop_out_pressed):
		pop_out_btn.pressed.connect(_on_pop_out_pressed)
	# Capture-category toggles re-send the subscription on change.
	if lifecycle_check_box and not lifecycle_check_box.toggled.is_connected(_on_category_toggled):
		lifecycle_check_box.toggled.connect(_on_category_toggled)
	if (
		prop_changes_check_box
		and not prop_changes_check_box.toggled.is_connected(_on_category_toggled)
	):
		prop_changes_check_box.toggled.connect(_on_category_toggled)
	if metrics_check_box and not metrics_check_box.toggled.is_connected(_on_category_toggled):
		metrics_check_box.toggled.connect(_on_category_toggled)
	if (
		metrics_hz_spin_box
		and not metrics_hz_spin_box.value_changed.is_connected(_on_metrics_hz_changed)
	):
		metrics_hz_spin_box.value_changed.connect(_on_metrics_hz_changed)
	# Connect to system tree for clicking (single click to toggle)
	if (
		system_tree
		and not system_tree.item_mouse_selected.is_connected(_on_system_tree_item_mouse_selected)
	):
		system_tree.item_mouse_selected.connect(_on_system_tree_item_mouse_selected)
	# Connect to system tree for column clicking (for sorting)
	if (
		system_tree
		and not system_tree.column_title_clicked.is_connected(_on_system_tree_column_clicked)
	):
		system_tree.column_title_clicked.connect(_on_system_tree_column_clicked)
	# Connect to entities tree for column clicking (for sorting)
	if (
		entities_tree
		and not entities_tree.column_title_clicked.is_connected(_on_entities_tree_column_clicked)
	):
		entities_tree.column_title_clicked.connect(_on_entities_tree_column_clicked)
	# Connect to entities tree for right-click context menu
	if (
		entities_tree
		and not entities_tree.item_mouse_selected.is_connected(
			_on_entities_tree_item_mouse_selected
		)
	):
		entities_tree.item_mouse_selected.connect(_on_entities_tree_item_mouse_selected)
	# Connect to system tree for right-click context menu
	if system_tree and not system_tree.button_clicked.is_connected(_on_system_tree_button_clicked):
		system_tree.button_clicked.connect(_on_system_tree_button_clicked)
	# Manual column resizing (Godot's Tree has no built-in drag-to-resize).
	if system_tree and not system_tree.gui_input.is_connected(_on_tree_gui_input):
		system_tree.gui_input.connect(_on_tree_gui_input.bind(system_tree))
	if entities_tree and not entities_tree.gui_input.is_connected(_on_tree_gui_input):
		entities_tree.gui_input.connect(_on_tree_gui_input.bind(entities_tree))
	# Query mode: checkbox flips the entities filter box between text-filter and
	# running a typed QueryBuilder expression in the game (submit on Enter).
	if query_builder_check_box and not query_builder_check_box.toggled.is_connected(
		_on_query_mode_toggled
	):
		query_builder_check_box.toggled.connect(_on_query_mode_toggled)
	if entities_filter_line_edit and not entities_filter_line_edit.text_submitted.is_connected(
		_on_entities_query_submitted
	):
		entities_filter_line_edit.text_submitted.connect(_on_entities_query_submitted)


func _process(delta: float) -> void:
	# Poll expanded entities for live component data updates
	var poll_hz: float = poll_rate_spin_box.value if poll_rate_spin_box else 0.0
	if poll_hz <= 0.0 or not active:
		return
	_poll_elapsed += delta
	var poll_interval := 1.0 / poll_hz
	if _poll_elapsed < poll_interval:
		return
	_poll_elapsed = 0.0
	_poll_expanded_entities()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_match_theme_to_editor_luminance()


func _match_theme_to_editor_luminance() -> void:
	var editor_base_color: Color = get_theme_color("base_color", "Editor")
	if editor_base_color.get_luminance() < 0.5:
		theme = null # No theme defaults to a dark style
	else:
		theme = load("uid://c1k1244qg6usg") # Load: gecs_editor_debugger_tab_light_theme.tres


func _update_debug_mode_overlay() -> void:
	if not debug_mode_overlay:
		return

	# Check if debug mode is enabled in project settings
	var debug_enabled = ProjectSettings.get_setting(GecsSettings.SETTINGS_DEBUG_MODE, false)

	# Show overlay if debug mode is disabled, hide if enabled
	debug_mode_overlay.visible = not debug_enabled


# --- External setters expected by debugger plugin ---
func set_debugger_session(_session):
	# Store session reference for sending messages to game
	_debugger_session = _session


func set_editor_interface(_editor_interface):
	# Store editor interface reference for future use (e.g., selecting nodes)
	# Currently not used, but expected by the debugger plugin
	pass


# Send a message from editor to the running game
func send_to_game(message: String, data: Array = []) -> bool:
	if _debugger_session == null:
		push_warning("GECS Debug: No active debugger session")
		return false
	_debugger_session.send_message(message, data)
	return true


## Reply to the game's READY announcement with a subscription reflecting the
## current category toggles. The game replays a full snapshot in response so the
## trees populate immediately.
func on_game_ready() -> void:
	_send_subscription()


## Build and send the subscription from the current toggle/Hz state. Called on the
## READY handshake and whenever a category toggle or the Hz spinner changes.
func _send_subscription() -> void:
	# The checkboxes may not exist yet if called before _ready(); default to on.
	var lifecycle := lifecycle_check_box.button_pressed if lifecycle_check_box else true
	var props := prop_changes_check_box.button_pressed if prop_changes_check_box else true
	var metrics := metrics_check_box.button_pressed if metrics_check_box else true
	var hz := metrics_hz_spin_box.value if metrics_hz_spin_box else 10.0
	send_to_game(
		"gecs:subscribe",
		[
			{
				"system_metrics": metrics,
				"entity_lifecycle": lifecycle,
				"property_changes": props,
			},
			hz,
		]
	)


func _on_category_toggled(_pressed: bool) -> void:
	_send_subscription()


func _on_metrics_hz_changed(_value: float) -> void:
	_send_subscription()


## Poll only expanded entity tree items for fresh component data.
## This keeps the debugger updated without requiring components to have explicit setters,
## and stays cheap by only polling what the user is actually looking at.
func _poll_expanded_entities() -> void:
	if not entities_tree or not entities_tree.get_root():
		return
	var child = entities_tree.get_root().get_first_child()
	while child:
		# Only poll entities that are expanded (user is viewing their components)
		if not child.collapsed:
			var entity_id = child.get_meta("entity_id", null)
			if entity_id != null:
				send_to_game("gecs:poll_entity", [entity_id])
		child = child.get_next()


func clear_all_data():
	ecs_data.clear()
	_pending_components.clear()
	# Drop any active query filter/results from the previous session.
	_query_active = false
	_query_result_ids.clear()
	_query_status_text = ""

	# Clear system tree
	if system_tree:
		system_tree.clear()
		# Recreate root
		system_tree.create_item()

	# Clear entities tree
	if entities_tree:
		entities_tree.clear()
		# Recreate root
		entities_tree.create_item()

	# Reset status bars
	_update_entity_status_bar()
	_update_systems_status_bar()


# ---- Filters & Refresh Helpers ----
func _on_entities_filter_changed(new_text: String):
	# In query mode the box holds a QueryBuilder expression that only runs on
	# Enter — don't treat every keystroke as a text filter.
	if _query_mode:
		return
	_refresh_entity_tree_filter()


## Toggle the entities filter box between text-filter and query-expression mode.
func _on_query_mode_toggled(pressed: bool) -> void:
	_query_mode = pressed
	if entities_filter_line_edit:
		entities_filter_line_edit.placeholder_text = (
			"q.with_all([C_A]).with_none([C_B])  (Enter to run)"
			if pressed
			else "Entities filter....."
		)
	if pressed:
		# Leaving text-filter: show everything until a query runs.
		_reset_entity_visibility()
	else:
		# Leaving query mode: drop query results and re-apply any text filter.
		_query_active = false
		_query_result_ids.clear()
		_query_status_text = ""
		_refresh_entity_tree_filter()
	_update_entity_status_bar()


## Submit handler for the filter box. Only meaningful in query mode (Enter runs it).
func _on_entities_query_submitted(text: String) -> void:
	if not _query_mode:
		return
	var query_text := text.strip_edges()
	if query_text == "":
		_query_active = false
		_query_result_ids.clear()
		_query_status_text = ""
		_reset_entity_visibility()
		_update_entity_status_bar()
		return
	if not send_to_game("gecs:run_entity_query", [query_text]):
		_query_status_text = "Query: no active debug session"
		_update_entity_status_bar()


## Receive query results from the game and filter the tree to matching entities.
func entity_query_result(entity_ids: Array, error: String) -> void:
	if error != "":
		_query_active = false
		_query_result_ids.clear()
		_reset_entity_visibility()
		_query_status_text = "Query error: " + str(error)
		_update_entity_status_bar()
		return
	_query_result_ids.clear()
	for id in entity_ids:
		_query_result_ids[id] = true
	_query_active = true
	# Show only matching entities.
	if entities_tree and entities_tree.get_root():
		var item = entities_tree.get_root().get_first_child()
		while item:
			var eid = item.get_meta("entity_id", null)
			item.visible = eid != null and _query_result_ids.has(eid)
			item = item.get_next()
	_query_status_text = "Query matched %d entities" % entity_ids.size()
	_update_entity_status_bar()


## Make every top-level entity row visible (clears any active filter).
func _reset_entity_visibility() -> void:
	if not entities_tree or not entities_tree.get_root():
		return
	var item = entities_tree.get_root().get_first_child()
	while item:
		item.visible = true
		item = item.get_next()


func _on_systems_filter_changed(new_text: String):
	_refresh_system_tree_filter()


# ---- Button Handlers ----
func _on_collapse_all_pressed():
	collapse_all_entities()


func _on_expand_all_pressed():
	expand_all_entities()


func _on_systems_collapse_all_pressed():
	collapse_all_systems()


func _on_systems_expand_all_pressed():
	expand_all_systems()


func _on_pop_out_pressed():
	if _popup_window != null:
		# Window already exists, close it and restore content
		_on_popup_window_closed()
		return

	# Create a new window
	_popup_window = Window.new()
	_popup_window.title = "GECS Debug Viewer"
	_popup_window.size = Vector2i(1200, 800)
	_popup_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS

	# Move the main content to the window (not duplicate)
	var hsplit = get_node("HSplit")
	remove_child(hsplit)
	_popup_window.add_child(hsplit)

	# Add window to the scene tree
	add_child(_popup_window)

	# Connect close signal
	_popup_window.close_requested.connect(_on_popup_window_closed)

	# Show the window
	_popup_window.show()

	# Update the button text
	pop_out_btn.text = "Pop In"


func _on_popup_window_closed():
	if _popup_window != null:
		# Move content back to main tab
		var hsplit = _popup_window.get_node("HSplit")
		_popup_window.remove_child(hsplit)
		add_child(hsplit)
		move_child(hsplit, 0)  # Move to beginning

		# Close and cleanup window
		_popup_window.queue_free()
		_popup_window = null
		pop_out_btn.text = "Pop Out"


func _on_system_tree_item_mouse_selected(position: Vector2, mouse_button_index: int):
	# When user clicks on a system tree item, check if clicking on status column to toggle or right-click for menu
	var selected = system_tree.get_selected()
	if not selected:
		return

	# Check if has system_id metadata with safe default
	var system_id = selected.get_meta("system_id", null)
	if system_id == null:
		return

	# Only process top-level system items (not child details)
	if selected.get_parent() == system_tree.get_root():
		if mouse_button_index == MOUSE_BUTTON_LEFT:
			# Get the column that was clicked
			var column = system_tree.get_column_at_position(position)
			if column == 6:  # Status column
				_toggle_system_active()
		elif mouse_button_index == MOUSE_BUTTON_RIGHT:
			_show_system_context_menu(selected, position)


func _on_system_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int):
	# Handle button clicks in tree (currently unused, but keeping for future)
	pass


## Emulated column resizing — Godot's Tree has no built-in drag-to-resize
## (godot-proposals#2088). Grab a column's right edge in the title band and drag.
func _on_tree_gui_input(event: InputEvent, tree: Tree) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var col := _column_boundary_at(tree, event.position)
			if col != -1:
				_resizing_tree = tree
				_resize_column = col
				_resize_start_x = event.position.x
				_resize_start_width = tree.get_column_width(col)
				tree.accept_event()  # consume so this press doesn't sort/select
		elif _resizing_tree == tree:
			_resizing_tree = null
			_resize_column = -1
			tree.accept_event()
	elif event is InputEventMouseMotion:
		if _resizing_tree == tree and _resize_column != -1:
			var new_w := int(maxf(24.0, _resize_start_width + (event.position.x - _resize_start_x)))
			# A resized column becomes fixed-width so the custom width sticks.
			tree.set_column_expand(_resize_column, false)
			tree.set_column_custom_minimum_width(_resize_column, new_w)
			tree.accept_event()
		else:
			# Cursor feedback when hovering a resizable boundary.
			var hover := _column_boundary_at(tree, event.position)
			tree.mouse_default_cursor_shape = (
				Control.CURSOR_HSIZE if hover != -1 else Control.CURSOR_ARROW
			)


## Column whose RIGHT edge sits within grab distance of [param pos] (title band
## only), else -1. [param pos] is tree-local; accounts for horizontal scroll.
func _column_boundary_at(tree: Tree, pos: Vector2) -> int:
	if not tree.column_titles_visible or pos.y > _tree_title_height(tree):
		return -1
	var x := -tree.get_scroll().x
	for c in range(tree.columns):
		x += tree.get_column_width(c)
		if absf(pos.x - x) <= _RESIZE_GRAB_PX:
			return c
	return -1


## Best-effort height of the clickable column-title band.
func _tree_title_height(tree: Tree) -> float:
	var f := tree.get_theme_font("title_button_font")
	if f:
		var fs := tree.get_theme_font_size("title_button_font_size")
		return f.get_height(fs) + 8.0
	return 24.0


func _on_entities_tree_item_mouse_selected(position: Vector2, mouse_button_index: int):
	# Handle right-click on entity tree items
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return

	var selected = entities_tree.get_selected()
	if not selected:
		return

	# Check if has entity_id metadata (top-level entity item)
	var entity_id = selected.get_meta("entity_id", null)
	if entity_id == null:
		return

	# Only show context menu for top-level entity items
	if selected.get_parent() == entities_tree.get_root():
		_show_entity_context_menu(selected, position)


func _show_entity_context_menu(item: TreeItem, position: Vector2):
	var entity_id = item.get_meta("entity_id", null)
	if entity_id == null:
		return

	var popup = PopupMenu.new()
	add_child(popup)

	var is_pinned = _pinned_entities.get(entity_id, false)
	if is_pinned:
		popup.add_item("Unpin Entity", 0)
	else:
		popup.add_item("Pin Entity", 0)

	# Position the popup at the mouse position (use get_screen_position for proper screen coords)
	var screen_pos = entities_tree.get_screen_position() + position
	popup.position = screen_pos
	popup.popup()

	# Connect the selection signal
	popup.id_pressed.connect(
		func(id):
			if id == 0:
				_toggle_entity_pin(entity_id, item)
			popup.queue_free()
	)

	# Clean up when popup closes
	popup.popup_hide.connect(
		func():
			if is_instance_valid(popup):
				popup.queue_free()
	)


func _show_system_context_menu(item: TreeItem, position: Vector2):
	var system_id = item.get_meta("system_id", null)
	if system_id == null:
		return

	var popup = PopupMenu.new()
	add_child(popup)

	var is_pinned = _pinned_systems.get(system_id, false)
	if is_pinned:
		popup.add_item("Unpin System", 0)
	else:
		popup.add_item("Pin System", 0)

	# Position the popup at the mouse position (use get_screen_position for proper screen coords)
	var screen_pos = system_tree.get_screen_position() + position
	popup.position = screen_pos
	popup.popup()

	# Connect the selection signal
	popup.id_pressed.connect(
		func(id):
			if id == 0:
				_toggle_system_pin(system_id, item)
			popup.queue_free()
	)

	# Clean up when popup closes
	popup.popup_hide.connect(
		func():
			if is_instance_valid(popup):
				popup.queue_free()
	)


func _toggle_entity_pin(entity_id: int, item: TreeItem):
	var is_pinned = _pinned_entities.get(entity_id, false)
	_pinned_entities[entity_id] = not is_pinned
	_update_entity_pin_display(item, not is_pinned)
	# Re-sort to move pinned items to top
	if _entity_sort_column != -1 or not is_pinned:
		_sort_entity_tree()


func _toggle_system_pin(system_id: int, item: TreeItem):
	var is_pinned = _pinned_systems.get(system_id, false)
	_pinned_systems[system_id] = not is_pinned
	_update_system_pin_display(item, not is_pinned)
	# Re-sort to move pinned items to top
	if _system_sort_column != -1 or not is_pinned:
		_sort_system_tree()


func _update_entity_pin_display(item: TreeItem, is_pinned: bool):
	var current_text = item.get_text(0)
	# Remove existing pin icon if present
	if current_text.begins_with(ICON_PIN + " "):
		current_text = current_text.substr(2)

	if is_pinned:
		item.set_text(0, ICON_PIN + " " + current_text)
	else:
		item.set_text(0, current_text)


func _update_system_pin_display(item: TreeItem, is_pinned: bool):
	var current_text = item.get_text(0)  # Name is in column 0 now
	# Remove existing pin icon if present
	if current_text.begins_with(ICON_PIN + " "):
		current_text = current_text.substr(2)

	if is_pinned:
		item.set_text(0, ICON_PIN + " " + current_text)
	else:
		item.set_text(0, current_text)


func _toggle_system_active():
	var selected = system_tree.get_selected()
	if not selected:
		push_warning("GECS Debug: No system selected")
		return

	var system_id = selected.get_meta("system_id", null)
	if system_id == null:
		push_warning("GECS Debug: No system selected")
		return
	var systems_data = ecs_data.get("systems", {})
	var system_data = systems_data.get(system_id, {})
	var current_active = system_data.get("active", true)

	# Toggle the state
	var new_active = not current_active

	# Send message to game to toggle system active state
	send_to_game("gecs:set_system_active", [system_id, new_active])

	# Optimistically update local state (will be confirmed by game)
	system_data["active"] = new_active
	_update_system_active_display(selected, new_active)


func _update_system_active_display(system_item: TreeItem, is_active: bool):
	# Update the visual display of the system in column 6 (Status) as a button
	if is_active:
		system_item.set_text(6, "ACTIVE")
		system_item.set_custom_color(6, Color(0.5, 1.0, 0.5))  # Green text
	else:
		system_item.set_text(6, "INACTIVE")
		system_item.set_custom_color(6, Color(1.0, 0.3, 0.3))  # Red text

	# Make the status column a clickable button
	system_item.set_cell_mode(6, TreeItem.CELL_MODE_STRING)
	system_item.set_selectable(6, true)
	system_item.set_editable(6, false)


func _on_system_tree_column_clicked(column: int, mouse_button_index: int):
	# Only sort on left click
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	# Cycle through: None -> Asc -> Desc -> None
	if _system_sort_column == column:
		if _system_sort_ascending:
			# Currently ascending, switch to descending
			_system_sort_ascending = false
		else:
			# Currently descending, remove sorting
			_system_sort_column = -1
			_system_sort_ascending = true
	else:
		# New column, start with ascending
		_system_sort_column = column
		_system_sort_ascending = true

	# Update column title indicators
	_update_system_column_indicators()

	# Sort the tree
	_sort_system_tree()


func _update_system_column_indicators():
	# Keep this in sync with the 8-column layout set in _ready().
	const TITLES := [
		"Name",
		"Group",
		"Time (ms)",
		"Min (ms)",
		"Max (ms)",
		"Avg (ms)",
		"Status",
		"Order",
	]
	for i in range(TITLES.size()):
		var title: String = TITLES[i]
		if i == _system_sort_column:
			if _system_sort_ascending:
				title += " ▲"
			else:
				title += " ▼"
		system_tree.set_column_title(i, title)


func _sort_system_tree():
	if not system_tree:
		return

	var root = system_tree.get_root()
	if not root:
		return

	# Collect all system items with their data
	var systems: Array = []
	var pinned_systems: Array = []
	var child = root.get_first_child()
	while child:
		var system_id = child.get_meta("system_id", null)
		var system_data = {
			"item": child,
			"name": child.get_text(0),
			"group": child.get_text(1),
			"time": 0.0,
			"min": 0.0,
			"max": 0.0,
			"avg": 0.0,
			"status": child.get_text(6),
			"order": int(child.get_text(7)) if child.get_text(7).is_valid_int() else 0,
			"system_id": system_id,
			"is_pinned": _pinned_systems.get(system_id, false),
		}

		# Parse ms values (strip " ms" suffix if present)
		var time_text = child.get_text(2)
		if time_text:
			system_data["time"] = float(time_text.replace(" ms", ""))
		var min_text = child.get_text(3)
		if min_text:
			system_data["min"] = float(min_text.replace(" ms", ""))
		var max_text = child.get_text(4)
		if max_text:
			system_data["max"] = float(max_text.replace(" ms", ""))
		var avg_text = child.get_text(5)
		if avg_text:
			system_data["avg"] = float(avg_text.replace(" ms", ""))

		if system_data["is_pinned"]:
			pinned_systems.append(system_data)
		else:
			systems.append(system_data)
		child = child.get_next()

	# Sort based on column (if sorting is active)
	if _system_sort_column != -1:
		match _system_sort_column:
			0:  # Name
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["name"].nocasecmp_to(b["name"]) < 0)
				else:
					systems.sort_custom(func(a, b): return a["name"].nocasecmp_to(b["name"]) > 0)
			1:  # Group
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["group"].nocasecmp_to(b["group"]) < 0)
				else:
					systems.sort_custom(func(a, b): return a["group"].nocasecmp_to(b["group"]) > 0)
			2:  # Time
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["time"] < b["time"])
				else:
					systems.sort_custom(func(a, b): return a["time"] > b["time"])
			3:  # Min
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["min"] < b["min"])
				else:
					systems.sort_custom(func(a, b): return a["min"] > b["min"])
			4:  # Max
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["max"] < b["max"])
				else:
					systems.sort_custom(func(a, b): return a["max"] > b["max"])
			5:  # Avg
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["avg"] < b["avg"])
				else:
					systems.sort_custom(func(a, b): return a["avg"] > b["avg"])
			6:  # Status
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["status"] < b["status"])
				else:
					systems.sort_custom(func(a, b): return a["status"] > b["status"])
			7:  # Order
				if _system_sort_ascending:
					systems.sort_custom(func(a, b): return a["order"] < b["order"])
				else:
					systems.sort_custom(func(a, b): return a["order"] > b["order"])

	# Rebuild tree: pinned items first, then sorted items
	for system_data in pinned_systems:
		var item = system_data["item"]
		root.remove_child(item)
		root.add_child(item)
	for system_data in systems:
		var item = system_data["item"]
		root.remove_child(item)
		root.add_child(item)


func _on_entities_tree_column_clicked(column: int, mouse_button_index: int):
	# Only sort on left click
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	# Cycle through: None -> Asc -> Desc -> None
	if _entity_sort_column == column:
		if _entity_sort_ascending:
			# Currently ascending, switch to descending
			_entity_sort_ascending = false
		else:
			# Currently descending, remove sorting
			_entity_sort_column = -1
			_entity_sort_ascending = true
	else:
		# New column, start with ascending
		_entity_sort_column = column
		_entity_sort_ascending = true

	# Update column title indicators
	_update_entity_column_indicators()

	# Sort the tree
	_sort_entity_tree()


func _update_entity_column_indicators():
	# Clear all column indicators first
	for i in range(4):
		var title = ""
		match i:
			0:
				title = "Entity"
			1:
				title = "Comps"
			2:
				title = "Rels"
			3:
				title = "Nodes"

		# Add arrow indicator if this is the sort column
		if i == _entity_sort_column:
			if _entity_sort_ascending:
				title += " ▲"
			else:
				title += " ▼"

		entities_tree.set_column_title(i, title)


func _sort_entity_tree():
	if not entities_tree:
		return

	var root = entities_tree.get_root()
	if not root:
		return

	# Collect all entity items with their data
	var entities: Array = []
	var pinned_entities: Array = []
	var child = root.get_first_child()
	while child:
		var entity_id = child.get_meta("entity_id", null)
		var entity_data = {
			"item": child,
			"name": child.get_text(0),
			"comps": 0,
			"rels": 0,
			"nodes": 0,
			"entity_id": entity_id,
			"is_pinned": _pinned_entities.get(entity_id, false),
		}

		# Get numeric counts from columns
		var comps_text = child.get_text(1)
		if comps_text:
			entity_data["comps"] = int(comps_text)

		var rels_text = child.get_text(2)
		if rels_text:
			entity_data["rels"] = int(rels_text)

		var nodes_text = child.get_text(3)
		if nodes_text:
			entity_data["nodes"] = int(nodes_text)

		if entity_data["is_pinned"]:
			pinned_entities.append(entity_data)
		else:
			entities.append(entity_data)
		child = child.get_next()

	# Sort based on column (if sorting is active)
	if _entity_sort_column != -1:
		match _entity_sort_column:
			0:  # Name
				if _entity_sort_ascending:
					entities.sort_custom(func(a, b): return a["name"].nocasecmp_to(b["name"]) < 0)
				else:
					entities.sort_custom(func(a, b): return a["name"].nocasecmp_to(b["name"]) > 0)
			1:  # Components
				if _entity_sort_ascending:
					entities.sort_custom(func(a, b): return a["comps"] < b["comps"])
				else:
					entities.sort_custom(func(a, b): return a["comps"] > b["comps"])
			2:  # Relationships
				if _entity_sort_ascending:
					entities.sort_custom(func(a, b): return a["rels"] < b["rels"])
				else:
					entities.sort_custom(func(a, b): return a["rels"] > b["rels"])
			3:  # Nodes
				if _entity_sort_ascending:
					entities.sort_custom(func(a, b): return a["nodes"] < b["nodes"])
				else:
					entities.sort_custom(func(a, b): return a["nodes"] > b["nodes"])

	# Rebuild tree: pinned items first, then sorted items
	for entity_data in pinned_entities:
		var item = entity_data["item"]
		root.remove_child(item)
		root.add_child(item)
	for entity_data in entities:
		var item = entity_data["item"]
		root.remove_child(item)
		root.add_child(item)


# --- Utilities ---
func get_or_create_dict(dict: Dictionary, key, default_val = {}) -> Dictionary:
	if not dict.has(key):
		dict[key] = default_val
	return dict[key]


func collapse_all_entities():
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		_collapse_item_recursive(item)
		item = item.get_next()


func expand_all_entities():
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		_expand_item_recursive(item)
		item = item.get_next()


func collapse_all_systems():
	if not system_tree:
		return
	var root = system_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		_collapse_item_recursive(item)
		item = item.get_next()


func expand_all_systems():
	if not system_tree:
		return
	var root = system_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		_expand_item_recursive(item)
		item = item.get_next()


func _collapse_item_recursive(item: TreeItem):
	if item == null:
		return
	item.collapsed = true
	var child = item.get_first_child()
	while child:
		_collapse_item_recursive(child)
		child = child.get_next()


func _expand_item_recursive(item: TreeItem):
	if item == null:
		return
	item.collapsed = false
	var child = item.get_first_child()
	while child:
		_expand_item_recursive(child)
		child = child.get_next()


# ---- Filters ----
func _refresh_system_tree_filter():
	if not system_tree:
		return
	var root = system_tree.get_root()
	if root == null:
		return
	var filter = systems_filter_line_edit.text.to_lower() if systems_filter_line_edit else ""
	var item = root.get_first_child()
	while item:
		var name = item.get_text(0).to_lower()
		item.visible = filter == "" or name.find(filter) != -1
		item = item.get_next()


func _refresh_entity_tree_filter():
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var filter = entities_filter_line_edit.text.to_lower() if entities_filter_line_edit else ""
	var item = root.get_first_child()
	while item:
		var label = item.get_text(0).to_lower()
		var matches = filter == "" or label.find(filter) != -1
		if not matches:
			var comp_child = item.get_first_child()
			while comp_child and not matches:
				if comp_child.get_text(0).to_lower().find(filter) != -1:
					matches = true
					break
				var prop_row = comp_child.get_first_child()
				while prop_row and not matches:
					if prop_row.get_text(0).to_lower().find(filter) != -1:
						matches = true
						break
					prop_row = prop_row.get_next()
				comp_child = comp_child.get_next()
		item.visible = matches
		item = item.get_next()


func world_init(world_id: int, world_path: NodePath):
	# Initialize world tracking
	var world_dict := get_or_create_dict(ecs_data, "world")
	world_dict["id"] = world_id
	world_dict["path"] = world_path
	# Update debug mode overlay in case settings changed
	_update_debug_mode_overlay()


func set_world(world_id: int, world_path: NodePath):
	# Set or update current world
	var world_dict := get_or_create_dict(ecs_data, "world")
	world_dict["id"] = world_id
	world_dict["path"] = world_path


func process_world(delta: float, group_name: String):
	var world_dict := get_or_create_dict(ecs_data, "world")
	world_dict["delta"] = delta
	world_dict["active_group"] = group_name


func exit_world():
	ecs_data["exited"] = true


func _update_entity_counts(entity_item: TreeItem, ent_id: int):
	# Update the count columns for an entity
	if not entity_item:
		return

	var entities = ecs_data.get("entities", {})
	var entity_data = entities.get(ent_id, {})

	# Count components
	var components = entity_data.get("components", {})
	entity_item.set_text(1, str(components.size()))

	# Count relationships
	var relationships = entity_data.get("relationships", {})
	entity_item.set_text(2, str(relationships.size()))

	# Count child nodes (entities tree doesn't track this from game data)
	# We'll count the child TreeItems instead (components + relationships)
	var child_count = 0
	var child = entity_item.get_first_child()
	while child:
		# Count only component and relationship children, not property rows
		if child.has_meta("component_id") or child.has_meta("relationship_id"):
			child_count += 1
		child = child.get_next()
	entity_item.set_text(3, str(child_count))


func _is_flag_component(component_data: Dictionary) -> bool:
	# A flag component has no serializable properties
	# Check if data is empty or only has the placeholder
	if component_data.is_empty():
		return true
	if component_data.size() == 1 and component_data.has("<no_serialized_properties>"):
		return true
	return false


func entity_added(ent: int, path: NodePath) -> void:
	var entities := get_or_create_dict(ecs_data, "entities")
	# Merge with any existing (temporary) entry that may already have buffered components/relationships
	var existing := entities.get(ent, {})
	var existing_components: Dictionary = existing.get("components", {})
	var existing_relationships: Dictionary = existing.get("relationships", {})
	# Update in place instead of overwrite to avoid losing buffered component data
	entities[ent] = {
		"path": path,
		"active": true,
		"components": existing_components,
		"relationships": existing_relationships,
	}
	# Add to entities tree
	if entities_tree:
		var root = entities_tree.get_root()
		if root == null:
			root = entities_tree.create_item()
		var item = entities_tree.create_item(root)
		# Column 0: Entity name with icon (and pin icon if pinned)
		var display_name = ICON_ENTITY + " " + str(path).get_file()
		if _pinned_entities.get(ent, false):
			display_name = ICON_PIN + " " + display_name
		item.set_text(0, display_name)
		item.set_tooltip_text(0, str(ent) + " : " + str(path))
		# Columns 1-3: Counts (will be updated as components/relationships are added)
		item.set_text(1, "0")
		item.set_text(2, "0")
		item.set_text(3, "0")
		item.set_meta("entity_id", ent)
		item.set_meta("path", path)
		item.collapsed = true  # Start collapsed
		# Flush any pending components that arrived before the entity node was created
		if _pending_components.has(ent):
			for comp_info in _pending_components[ent]:
				_attach_component_to_entity_item(
					item, ent, comp_info.comp_id, comp_info.comp_path, comp_info.data
				)
			_pending_components.erase(ent)
		# Update counts
		_update_entity_counts(item, ent)

	# Re-sort if we have an active sort column
	if _entity_sort_column != -1:
		_sort_entity_tree()

	_update_entity_status_bar()


func entity_removed(ent: int, path: NodePath) -> void:
	var entities := get_or_create_dict(ecs_data, "entities")
	entities.erase(ent)
	# Remove from tree
	if entities_tree and entities_tree.get_root():
		var root = entities_tree.get_root()
		var child = root.get_first_child()
		while child:
			if child.get_meta("entity_id", null) == ent:
				child.free()
				break
			child = child.get_next()

	# Clean up pinned state
	_pinned_entities.erase(ent)

	_update_entity_status_bar()


func entity_disabled(ent: int, path: NodePath) -> void:
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent):
		entities[ent]["active"] = false
	if entities_tree and entities_tree.get_root():
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id", null) == ent:
				child.set_text(0, child.get_text(0) + " (disabled)")
				break
			child = child.get_next()


func entity_enabled(ent: int, path: NodePath) -> void:
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent):
		entities[ent]["active"] = true
	if entities_tree and entities_tree.get_root():
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id", null) == ent:
				# Remove any (disabled) suffix
				var txt = child.get_text(0)
				if txt.ends_with(" (disabled)"):
					child.set_text(0, txt.substr(0, txt.length() - 11))
				break
			child = child.get_next()


func system_added(
	sys: int,
	group: String,
	process_empty: bool,
	active: bool,
	paused: bool,
	path: NodePath,
) -> void:
	var systems_data := get_or_create_dict(ecs_data, "systems")
	systems_data[sys] = default_system.duplicate()
	systems_data[sys]["path"] = path
	systems_data[sys]["group"] = group
	systems_data[sys]["process_empty"] = process_empty
	systems_data[sys]["active"] = active
	systems_data[sys]["paused"] = paused

	_update_systems_status_bar()


func system_removed(sys: int, path: NodePath) -> void:
	var systems_data := get_or_create_dict(ecs_data, "systems")
	systems_data.erase(sys)

	# Clean up pinned state
	_pinned_systems.erase(sys)

	_update_systems_status_bar()


func system_metric(system: int, system_name: String, time: float):
	var systems_data := get_or_create_dict(ecs_data, "systems")
	var sys_entry := get_or_create_dict(systems_data, system, default_system.duplicate())
	# Track the last run time separately so it's always visible even when aggregation occurs
	sys_entry["last_time"] = time
	var sys_metrics = ecs_data["systems"][system]["metrics"]
	if not sys_metrics:
		# Initialize metrics if not present. count starts at 0 because the
		# unconditional increment below produces count=1 for the first sample.
		sys_metrics = {
			"min_time": time, "max_time": time, "avg_time": 0.0, "count": 0, "last_time": time
		}

	sys_metrics["min_time"] = min(sys_metrics["min_time"], time)
	sys_metrics["max_time"] = max(sys_metrics["max_time"], time)
	sys_metrics["count"] += 1
	sys_metrics["avg_time"] = (
		((sys_metrics["avg_time"] * (sys_metrics["count"] - 1)) + time) / sys_metrics["count"]
	)
	sys_metrics["last_time"] = time
	ecs_data["systems"][system]["metrics"] = sys_metrics

	_update_systems_status_bar()


func system_last_run_data(system_id: int, system_name: String, last_run_data: Dictionary):
	var systems_data := get_or_create_dict(ecs_data, "systems")
	var sys_entry := get_or_create_dict(systems_data, system_id, default_system.duplicate())
	sys_entry["last_run_data"] = last_run_data
	# Runtime ships pre-aggregated min_ms / max_ms / avg_ms / sample_count inside
	# last_run_data — no local aggregation needed. This is robust to debugger
	# message drops (e.g. under heavy entity spawn bursts): every frame still
	# contributes on the runtime side, so peaks are never lost.
	var exec_ms = last_run_data.get("execution_time_ms", 0.0)
	# Update or create tree item
	if system_tree:
		var root = system_tree.get_root()
		if root == null:
			root = system_tree.create_item()
		# Try to find existing item by metadata matching system_id
		var existing: TreeItem = null
		var child = root.get_first_child()
		while child != null:
			if child.get_meta("system_id", null) == system_id:
				existing = child
				break
			child = child.get_next()
		if existing == null:
			existing = system_tree.create_item(root)
			existing.set_meta("system_id", system_id)
			existing.collapsed = true  # Start collapsed

		# Set main system name in column 0
		var display_name = system_name
		# Check if this system is pinned and update display
		if _pinned_systems.get(system_id, false):
			if not display_name.begins_with(ICON_PIN + " "):
				display_name = ICON_PIN + " " + display_name
		existing.set_text(0, display_name)
		# Tooltip reveals the full name when the column clips it
		existing.set_tooltip_text(0, system_name)

		# Set group in column 1
		var group = sys_entry.get("group", "")
		existing.set_text(1, group)
		existing.set_tooltip_text(1, group)

		# Set execution time in column 2
		existing.set_text(2, String.num(exec_ms, 3) + " ms")

		# Set min/max/avg in columns 3/4/5 (pre-aggregated by the runtime)
		var min_ms = last_run_data.get("min_ms", exec_ms)
		var max_ms = last_run_data.get("max_ms", exec_ms)
		var avg_ms = last_run_data.get("avg_ms", exec_ms)
		existing.set_text(3, String.num(min_ms, 3) + " ms")
		existing.set_text(4, String.num(max_ms, 3) + " ms")
		existing.set_text(5, String.num(avg_ms, 3) + " ms")

		# Set active status in column 6
		var is_active = sys_entry.get("active", true)
		_update_system_active_display(existing, is_active)

		# Get execution order (index in systems array from last_run_data) - column 7
		var execution_order = last_run_data.get("execution_order", -1)
		if execution_order >= 0:
			existing.set_text(7, str(execution_order))
		else:
			existing.set_text(7, "-")
		# Clear previous children to avoid stale data
		var prev_child = existing.get_first_child()
		while prev_child:
			var next_child = prev_child.get_next()
			prev_child.free()
			prev_child = next_child
		# Create nested rows for key info (min/max/avg now in columns — keep samples + entity/arch here)
		var ent_count = last_run_data.get("entity_count", null)
		var arch_count = last_run_data.get("archetype_count", null)
		var parallel = last_run_data.get("parallel", false)
		var nested_data := {
			"samples": last_run_data.get("sample_count", 1),
			"entity_count": ent_count,
			"archetype_count": arch_count,
			"parallel": parallel,
		}
		for k in nested_data.keys():
			var v = nested_data[k]
			if v == null:
				continue
			var row = system_tree.create_item(existing)
			row.set_text(0, str(k) + ": " + str(v))
		# Subsystem details (numeric keys in last_run_data)
		for key in last_run_data.keys():
			if typeof(key) == TYPE_INT and last_run_data[key] is Dictionary:
				var sub = last_run_data[key]
				var sub_row = system_tree.create_item(existing)
				sub_row.set_text(
					0,
					"subsystem[" + str(key) + "] entity_count: " + str(sub.get("entity_count", 0))
				)
		# Optionally store raw json in metadata for tooltip or future expansion
		existing.set_meta("last_run_data", last_run_data.duplicate())

	# Re-sort if we have an active sort column
	if _system_sort_column != -1:
		_sort_system_tree()

	# Update status bar with latest system data
	_update_systems_status_bar()


func _on_systems_reset_metrics_pressed() -> void:
	# Tell the runtime to clear its per-system min/max/avg aggregates. Next frame's
	# lastRunData will arrive with sample_count=1 and the UI will rebuild from there.
	# NOTE: the "gecs:" prefix is required — the capture strips it before the game's
	# handler matches; without it the message never routed and this button did nothing.
	send_to_game("gecs:reset_system_metrics", [])
	# Optimistically clear the cached metrics so the UI doesn't show stale data
	# while we wait for the next telemetry frame.
	var systems_data = ecs_data.get("systems", {})
	for system_id in systems_data.keys():
		var sys = systems_data[system_id]
		var lrd = sys.get("last_run_data", {})
		if lrd is Dictionary:
			lrd["min_ms"] = lrd.get("execution_time_ms", 0.0)
			lrd["max_ms"] = lrd.get("execution_time_ms", 0.0)
			lrd["avg_ms"] = lrd.get("execution_time_ms", 0.0)
			lrd["sample_count"] = 0
	_update_systems_status_bar()


func entity_component_added(ent: int, comp: int, comp_path: String, data: Dictionary):
	var entities := get_or_create_dict(ecs_data, "entities")
	var entity := get_or_create_dict(entities, ent)
	if not entity.has("components"):
		entity["components"] = {}
	# Fallback: if serialized data is empty, attempt reflection of exported properties
	var final_data = data
	if final_data.is_empty():
		final_data = {}
		# Try to get the actual Object from instance_id (editor debugger gives us ID only). We can't reliably from here; leave empty.
		# As a workaround store a placeholder so UI shows component node.
		final_data["<no_serialized_properties>"] = true
	entity["components"][comp] = final_data
	# Update tree with component node and property children
	if entities_tree:
		var root = entities_tree.get_root()
		if root != null:
			var entity_item: TreeItem = null
			var child = root.get_first_child()
			while child:
				if child.get_meta("entity_id", null) == ent:
					entity_item = child
					break
				child = child.get_next()
			if entity_item:
				# Try to find existing component item to update instead of duplicating
				var existing_comp_item: TreeItem = null
				var comp_child = entity_item.get_first_child()
				while comp_child:
					if (
						comp_child.has_meta("component_id")
						and comp_child.get_meta("component_id") == comp
					):
						existing_comp_item = comp_child
						break
					comp_child = comp_child.get_next()
				if existing_comp_item:
					# Clear previous property rows
					var prev = existing_comp_item.get_first_child()
					while prev:
						var nxt = prev.get_next()
						prev.free()
						prev = nxt
					# Update title/path with icon
					var icon = ICON_FLAG if _is_flag_component(final_data) else ICON_COMPONENT
					existing_comp_item.set_text(0, icon + " " + comp_path.get_file().get_basename())
					existing_comp_item.set_tooltip_text(0, comp_path)
					existing_comp_item.set_meta("component_path", comp_path)
					_add_serialized_rows(existing_comp_item, final_data)
				else:
					_attach_component_to_entity_item(entity_item, ent, comp, comp_path, final_data)
				# Update entity counts
				_update_entity_counts(entity_item, ent)
			else:
				# Buffer component until entity_added arrives
				if not _pending_components.has(ent):
					_pending_components[ent] = []
				_pending_components[ent].append(
					{"comp_id": comp, "comp_path": comp_path, "data": final_data}
				)

	# Re-sort if we have an active sort column
	if _entity_sort_column != -1:
		_sort_entity_tree()

	_update_entity_status_bar()


func _attach_component_to_entity_item(
	entity_item: TreeItem, ent: int, comp: int, comp_path: String, final_data: Dictionary
) -> void:
	var comp_item = entities_tree.create_item(entity_item)
	# Use flag icon for components with no properties, otherwise use component icon
	var icon = ICON_FLAG if _is_flag_component(final_data) else ICON_COMPONENT
	comp_item.set_text(0, icon + " " + comp_path.get_file().get_basename())
	comp_item.set_tooltip_text(0, comp_path)
	comp_item.set_meta("component_id", comp)
	comp_item.set_meta("component_path", comp_path)
	comp_item.collapsed = true  # Start collapsed
	# Add property rows with recursive serialization
	_add_serialized_rows(comp_item, final_data)
	# Update entity counts
	_update_entity_counts(entity_item, ent)


func entity_component_removed(ent: int, comp: int):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("components"):
		entities[ent]["components"].erase(comp)
	if entities_tree and entities_tree.get_root():
		var entity_item: TreeItem = null
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id", null) == ent:
				entity_item = child
				break
			child = child.get_next()
		if entity_item:
			var comp_child = entity_item.get_first_child()
			while comp_child:
				if (
					comp_child.has_meta("component_id")
					and comp_child.get_meta("component_id") == comp
				):
					comp_child.free()
					break
				comp_child = comp_child.get_next()
			# Update entity counts
			_update_entity_counts(entity_item, ent)

	_update_entity_status_bar()


## Reconcile an entity's components against the authoritative id set from a poll.
## Removes any component (data + tree row) that the entity no longer has — covers
## removals whose lifecycle event was suppressed or missed.
func entity_components_synced(ent: int, comp_ids: Array):
	var id_set := {}
	for cid in comp_ids:
		id_set[cid] = true
	# Prune the editor-side mirror.
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("components"):
		var comps: Dictionary = entities[ent]["components"]
		for existing_id in comps.keys():
			if not id_set.has(existing_id):
				comps.erase(existing_id)
	# Prune the tree rows.
	if entities_tree and entities_tree.get_root():
		var entity_item: TreeItem = null
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id", null) == ent:
				entity_item = child
				break
			child = child.get_next()
		if entity_item:
			var comp_child = entity_item.get_first_child()
			while comp_child:
				var nxt = comp_child.get_next()
				if (
					comp_child.has_meta("component_id")
					and not id_set.has(comp_child.get_meta("component_id"))
				):
					comp_child.free()
				comp_child = nxt
			_update_entity_counts(entity_item, ent)

	_update_entity_status_bar()


func entity_component_property_changed(
	ent: int,
	comp: int,
	property_name: String,
	old_value: Variant,
	new_value: Variant,
):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("components"):
		var component = entities[ent]["components"].get(comp)
		if component:
			component[property_name] = new_value
	# Update tree property row
	if entities_tree and entities_tree.get_root():
		var entity_item: TreeItem = null
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id", null) == ent:
				entity_item = child
				break
			child = child.get_next()
		if entity_item:
			var comp_child = entity_item.get_first_child()
			while comp_child:
				if (
					comp_child.has_meta("component_id")
					and comp_child.get_meta("component_id") == comp
				):
					var prop_row = comp_child.get_first_child()
					var updated := false
					while prop_row:
						if (
							prop_row.has_meta("property_name")
							and prop_row.get_meta("property_name") == property_name
						):
							prop_row.set_text(0, property_name + ": " + str(new_value))
							updated = true
							break
						prop_row = prop_row.get_next()
					# If property row not found (added dynamically), append it
					if not updated:
						var new_row = entities_tree.create_item(comp_child)
						new_row.set_text(0, property_name + ": " + str(new_value))
						new_row.set_meta("property_name", property_name)
					# Done updating this component; no need to scan further
					break
				comp_child = comp_child.get_next()


# ---- Recursive Serialization Rendering ----
func _add_serialized_rows(parent_item: TreeItem, data: Dictionary):
	for key in data.keys():
		var value = data[key]
		var row = entities_tree.create_item(parent_item)
		row.set_text(0, str(key) + ": " + _value_to_string(value))
		row.set_meta("property_name", key)
		if value is Dictionary:
			_add_serialized_rows(row, value)
		elif value is Array:
			_add_array_rows(row, value)


func _add_array_rows(parent_item: TreeItem, arr: Array):
	for i in range(arr.size()):
		var value = arr[i]
		var row = entities_tree.create_item(parent_item)
		row.set_text(0, "[" + str(i) + "] " + _value_to_string(value))
		row.set_meta("property_name", str(i))
		if value is Dictionary:
			_add_serialized_rows(row, value)
		elif value is Array:
			_add_array_rows(row, value)


func _value_to_string(v):
	match typeof(v):
		TYPE_DICTIONARY:
			return "{...}"  # expanded in children
		TYPE_ARRAY:
			return "[..." + str(v.size()) + "]"
		TYPE_STRING:
			return '"' + v + '"'
		TYPE_OBJECT:
			if v is Resource:
				return "Resource(" + v.resource_path.get_file() + ")"
			return str(v)
		_:
			return str(v)


func entity_relationship_added(ent: int, rel: int, rel_data: Dictionary):
	var entities := get_or_create_dict(ecs_data, "entities")
	var entity := get_or_create_dict(entities, ent)
	var relationships := get_or_create_dict(entity, "relationships")
	relationships[rel] = rel_data

	# Add to tree
	if entities_tree:
		var root = entities_tree.get_root()
		if root != null:
			var entity_item: TreeItem = null
			var child = root.get_first_child()
			while child:
				if child.get_meta("entity_id", null) == ent:
					entity_item = child
					break
				child = child.get_next()

			if entity_item:
				# Try to find existing relationship item to update
				var existing_rel_item: TreeItem = null
				var rel_child = entity_item.get_first_child()
				while rel_child:
					if (
						rel_child.has_meta("relationship_id")
						and rel_child.get_meta("relationship_id") == rel
					):
						existing_rel_item = rel_child
						break
					rel_child = rel_child.get_next()

				if existing_rel_item:
					# Clear and rebuild
					var prev = existing_rel_item.get_first_child()
					while prev:
						var nxt = prev.get_next()
						prev.free()
						prev = nxt
					_update_relationship_item(existing_rel_item, rel_data)
				else:
					# Create new relationship item
					var rel_item = entities_tree.create_item(entity_item)
					rel_item.set_meta("relationship_id", rel)
					rel_item.collapsed = true  # Start collapsed
					_update_relationship_item(rel_item, rel_data)
				# Update entity counts
				_update_entity_counts(entity_item, ent)

	# Re-sort if we have an active sort column
	if _entity_sort_column != -1:
		_sort_entity_tree()

	_update_entity_status_bar()


func _update_relationship_item(rel_item: TreeItem, rel_data: Dictionary):
	# Format the relationship display
	var relation_type = rel_data.get("relation_type", "Unknown")
	var target_type = rel_data.get("target_type", "Unknown")

	# Build the title based on target type with relationship icon
	var title = ICON_RELATIONSHIP + " " + relation_type + " -> "
	if target_type == "Entity":
		var target_data = rel_data.get("target_data", {})
		title += "Entity " + str(target_data.get("path", "Unknown"))
	elif target_type == "Component":
		var target_data = rel_data.get("target_data", {})
		title += target_data.get("type", "Unknown")
	elif target_type == "Archetype":
		var target_data = rel_data.get("target_data", {})
		var script_path = target_data.get("script_path", "")
		title += "Archetype " + script_path.get_file().get_basename()
	elif target_type == "null":
		title += "Wildcard"
	else:
		title += target_type

	rel_item.set_text(0, title)

	# Add relation data as children
	var relation_data = rel_data.get("relation_data", {})
	if not relation_data.is_empty():
		var rel_data_item = entities_tree.create_item(rel_item)
		rel_data_item.set_text(0, "Relation Properties:")
		_add_serialized_rows(rel_data_item, relation_data)

	# Add target data as children (for components with properties)
	if target_type == "Component":
		var target_data = rel_data.get("target_data", {})
		var target_comp_data = target_data.get("data", {})
		if not target_comp_data.is_empty():
			var target_data_item = entities_tree.create_item(rel_item)
			target_data_item.set_text(0, "Target Properties:")
			_add_serialized_rows(target_data_item, target_comp_data)


func entity_relationship_removed(ent: int, rel: int):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("relationships"):
		entities[ent]["relationships"].erase(rel)

	# Remove from tree
	if entities_tree and entities_tree.get_root():
		var entity_item: TreeItem = null
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id", null) == ent:
				entity_item = child
				break
			child = child.get_next()

		if entity_item:
			var rel_child = entity_item.get_first_child()
			while rel_child:
				if (
					rel_child.has_meta("relationship_id")
					and rel_child.get_meta("relationship_id") == rel
				):
					rel_child.free()
					break
				rel_child = rel_child.get_next()
			# Update entity counts
			_update_entity_counts(entity_item, ent)

	_update_entity_status_bar()


# ---- Status Bar Updates ----


## Update the entity status bar with current counts
func _update_entity_status_bar():
	if not entity_status_bar:
		return

	var entities = ecs_data.get("entities", {})
	var entity_count = entities.size()

	# Count total components across all entities
	var total_components = 0
	for entity_data in entities.values():
		var components = entity_data.get("components", {})
		total_components += components.size()

	# Count total relationships across all entities
	var total_relationships = 0
	for entity_data in entities.values():
		var relationships = entity_data.get("relationships", {})
		total_relationships += relationships.size()

	var status := (
		"Entities: %d | Components: %d | Relationships: %d"
		% [
			entity_count,
			total_components,
			total_relationships,
		]
	)
	if _query_status_text != "":
		status += " | " + _query_status_text
	entity_status_bar.text = status


## Update the systems status bar with execution metrics
func _update_systems_status_bar():
	if not systems_status_bar:
		return

	var systems_data = ecs_data.get("systems", {})
	var system_count = systems_data.size()

	# Calculate total execution time and find most expensive system (current frame)
	var total_time_ms = 0.0
	var most_expensive_name = ""
	var most_expensive_time = 0.0
	# Also find peak system across metrics history (max_time)
	var peak_name = ""
	var peak_time = 0.0

	for system_id in systems_data.keys():
		var system_data = systems_data[system_id]
		# Get execution time from last_run_data if available (more accurate than last_time)
		var last_run_data = system_data.get("last_run_data", {})
		var exec_time_ms = last_run_data.get("execution_time_ms", 0.0)

		total_time_ms += exec_time_ms

		# Resolve a display name once per system
		var system_name = last_run_data.get("system_name", "")
		if not system_name:
			var path = system_data.get("path", "")
			if path:
				system_name = str(path).get_file().get_basename()
			else:
				system_name = "System_%d" % system_id

		if exec_time_ms > most_expensive_time:
			most_expensive_time = exec_time_ms
			most_expensive_name = system_name

		var metric_peak = last_run_data.get("max_ms", 0.0)
		if metric_peak > peak_time:
			peak_time = metric_peak
			peak_name = system_name

	# Format the status bar text — use 3 decimals so sub-millisecond systems
	# don't collapse to "0.0ms" and look broken.
	if most_expensive_name:
		systems_status_bar.text = (
			"Systems: %d | Total ms: %.3fms | Current Peak: %s (%.3fms) | All-Time Peak: %s (%.3fms)"
			% [
				system_count,
				total_time_ms,
				most_expensive_name,
				most_expensive_time,
				peak_name,
				peak_time,
			]
		)
	else:
		systems_status_bar.text = (
			"Systems: %d | Total ms: %.3fms"
			% [
				system_count,
				total_time_ms,
			]
		)
