@tool
class_name GECSEditorDebuggerTab
extends Control

@onready var query_builder_check_box: CheckBox = %QueryBuilderCheckBox
@onready var entities_filter_line_edit: LineEdit = %EntitiesQueryLineEdit
@onready var systems_filter_line_edit: LineEdit = %SystemsQueryLineEdit
@onready var collapse_all_btn: Button = %CollapseAllBtn
@onready var expand_all_btn: Button = %ExpandAllBtn
@onready var pop_out_btn: Button = %PopOutBtn
@onready var toggle_system_active_btn: Button = %ToggleSystemActiveBtn

var ecs_data: Dictionary = {}
var default_system := {"path": "", "active": true, "metrics": {}, "group": ""}
var default_entity := {"path": "", "active": true, "components": {}, "relationships": {}}
var timer = 5
var active := false
var _pending_components: Dictionary = {} # ent_id -> Array[Dictionary] of pending component data
var _popup_window: Window = null
var _debugger_session: EditorDebuggerSession = null

@onready var system_tree: Tree = %SystemsTree
@onready var entities_tree: Tree = %EntitiesTree


func _ready() -> void:
	if system_tree:
		# Two columns: name and active status
		system_tree.columns = 2
		system_tree.set_column_title(0, "System")
		system_tree.set_column_title(1, "Status")
		system_tree.set_column_titles_visible(true)
		system_tree.set_column_expand(0, true)
		system_tree.set_column_expand(1, false)
		system_tree.set_column_custom_minimum_width(1, 100)
		# Enable editing for status column (for click detection)
		system_tree.set_column_title_alignment(1, HORIZONTAL_ALIGNMENT_CENTER)
		# Create root item
		if system_tree.get_root() == null:
			system_tree.create_item()
	if entities_tree:
		entities_tree.columns = 1
		# Create root item
		if entities_tree.get_root() == null:
			entities_tree.create_item()
		# Polling & pinning removed; tree updates only via incoming messages
	if entities_filter_line_edit and not entities_filter_line_edit.text_changed.is_connected(_on_entities_filter_changed):
		entities_filter_line_edit.text_changed.connect(_on_entities_filter_changed)
	if systems_filter_line_edit and not systems_filter_line_edit.text_changed.is_connected(_on_systems_filter_changed):
		systems_filter_line_edit.text_changed.connect(_on_systems_filter_changed)
	if collapse_all_btn and not collapse_all_btn.pressed.is_connected(_on_collapse_all_pressed):
		collapse_all_btn.pressed.connect(_on_collapse_all_pressed)
	if expand_all_btn and not expand_all_btn.pressed.is_connected(_on_expand_all_pressed):
		expand_all_btn.pressed.connect(_on_expand_all_pressed)
	if pop_out_btn and not pop_out_btn.pressed.is_connected(_on_pop_out_pressed):
		pop_out_btn.pressed.connect(_on_pop_out_pressed)
	if toggle_system_active_btn and not toggle_system_active_btn.pressed.is_connected(_on_toggle_system_active_pressed):
		toggle_system_active_btn.pressed.connect(_on_toggle_system_active_pressed)
	# Connect to system tree for selection tracking
	if system_tree and not system_tree.item_selected.is_connected(_on_system_tree_item_selected):
		system_tree.item_selected.connect(_on_system_tree_item_selected)
	# Connect to system tree for clicking (single click to toggle)
	if system_tree and not system_tree.item_mouse_selected.is_connected(_on_system_tree_item_mouse_selected):
		system_tree.item_mouse_selected.connect(_on_system_tree_item_mouse_selected)


func _process(delta: float) -> void:
	# No periodic polling; rely on debugger messages only
	pass

# --- External setters expected by debugger plugin (no-op implementations) ---
func set_debugger_session(_session):
	# Store session reference for sending messages to game
	_debugger_session = _session

func set_editor_interface(_editor_interface):
	# Placeholder if future selection/inspection features are added
	pass

# Send a message from editor to the running game
func send_to_game(message: String, data: Array = []) -> bool:
	if _debugger_session == null:
		push_warning("GECS Debug: No active debugger session")
		return false
	_debugger_session.send_message(message, data)
	return true

func clear_all_data():
	ecs_data.clear()
	_pending_components.clear()

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

# ---- Filters & Refresh Helpers ----
func _on_entities_filter_changed(new_text: String):
	_refresh_entity_tree_filter()

func _on_systems_filter_changed(new_text: String):
	_refresh_system_tree_filter()

# ---- Button Handlers ----
func _on_collapse_all_pressed():
	collapse_all_entities()

func _on_expand_all_pressed():
	expand_all_entities()

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
		move_child(hsplit, 0) # Move to beginning

		# Close and cleanup window
		_popup_window.queue_free()
		_popup_window = null
		pop_out_btn.text = "Pop Out"

func _on_system_tree_item_selected():
	# Update toggle button state when a system is selected
	_update_toggle_system_active_button()

func _on_system_tree_item_mouse_selected(position: Vector2, mouse_button_index: int):
	# When user clicks on a system tree item, check if clicking on status column to toggle
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return

	var selected = system_tree.get_selected()
	if not selected or not selected.has_meta("system_id"):
		return

	# Only toggle if clicking on a top-level system item (not child details)
	if selected.get_parent() == system_tree.get_root():
		# Get the column that was clicked
		var column = system_tree.get_column_at_position(position)
		if column == 1:  # Status column
			_on_toggle_system_active_pressed()

func _on_toggle_system_active_pressed():
	var selected = system_tree.get_selected()
	if not selected or not selected.has_meta("system_id"):
		push_warning("GECS Debug: No system selected")
		return

	var system_id = selected.get_meta("system_id")
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

func _update_toggle_system_active_button():
	if not toggle_system_active_btn:
		return

	var selected = system_tree.get_selected()
	if not selected or not selected.has_meta("system_id"):
		toggle_system_active_btn.disabled = true
		toggle_system_active_btn.text = "Toggle Active"
		toggle_system_active_btn.modulate = Color.WHITE
		return

	var system_id = selected.get_meta("system_id")
	var systems_data = ecs_data.get("systems", {})
	var system_data = systems_data.get(system_id, {})
	var is_active = system_data.get("active", true)

	toggle_system_active_btn.disabled = false
	if is_active:
		toggle_system_active_btn.text = "ACTIVE"
		toggle_system_active_btn.modulate = Color(0.5, 1.0, 0.5) # Green tint
	else:
		toggle_system_active_btn.text = "NOT ACTIVE"
		toggle_system_active_btn.modulate = Color(1.0, 0.3, 0.3) # Red tint

func _update_system_active_display(system_item: TreeItem, is_active: bool):
	# Update the visual display of the system in column 1 as a button
	if is_active:
		system_item.set_text(1, "ACTIVE")
		system_item.set_custom_color(1, Color(0.5, 1.0, 0.5)) # Green text
	else:
		system_item.set_text(1, "INACTIVE")
		system_item.set_custom_color(1, Color(1.0, 0.3, 0.3)) # Red text

	# Make the status column a clickable button
	system_item.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
	system_item.set_selectable(1, true)
	system_item.set_editable(1, false)

	# Update the button state
	_update_toggle_system_active_button()

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
		item.collapsed = true
		item = item.get_next()

func expand_all_entities():
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		item.collapsed = false
		item = item.get_next()

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
		"relationships": existing_relationships
	}
	# Add to entities tree
	if entities_tree:
		var root = entities_tree.get_root()
		if root == null:
			root = entities_tree.create_item()
		var item = entities_tree.create_item(root)
		item.set_text(0, str(ent) + " : " + str(path))
		item.set_meta("entity_id", ent)
		item.set_meta("path", path)
		item.collapsed = true # Start collapsed
		# Flush any pending components that arrived before the entity node was created
		if _pending_components.has(ent):
			for comp_info in _pending_components[ent]:
				_attach_component_to_entity_item(item, ent, comp_info.comp_id, comp_info.comp_path, comp_info.data)
			_pending_components.erase(ent)


func entity_removed(ent: int, path: NodePath) -> void:
	var entities := get_or_create_dict(ecs_data, "entities")
	entities.erase(ent)
	# Remove from tree
	if entities_tree and entities_tree.get_root():
		var root = entities_tree.get_root()
		var child = root.get_first_child()
		while child:
			if child.get_meta("entity_id") == ent:
				root.remove_child(child)
				break
			child = child.get_next()


func entity_disabled(ent: int, path: NodePath) -> void:
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent):
		entities[ent]["active"] = false
	if entities_tree and entities_tree.get_root():
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id") == ent:
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
			if child.get_meta("entity_id") == ent:
				# Remove any (disabled) suffix
				var txt = child.get_text(0)
				if txt.ends_with(" (disabled)"):
					child.set_text(0, txt.substr(0, txt.length() - 11))
				break
			child = child.get_next()


func system_added(
	sys: int, group: String, process_empty: bool, active: bool, paused: bool, path: NodePath
) -> void:
	var systems_data := get_or_create_dict(ecs_data, "systems")
	systems_data[sys] = default_system.duplicate()
	systems_data[sys]["path"] = path
	systems_data[sys]["group"] = group
	systems_data[sys]["process_empty"] = process_empty
	systems_data[sys]["active"] = active
	systems_data[sys]["paused"] = paused


func system_removed(sys: int, path: NodePath) -> void:
	var systems_data := get_or_create_dict(ecs_data, "systems")
	systems_data.erase(sys)


func system_metric(system: int, system_name: String, time: float):
	var systems_data := get_or_create_dict(ecs_data, "systems")
	var sys_entry := get_or_create_dict(systems_data, system, default_system.duplicate())
	# Track the last run time separately so it's always visible even when aggregation occurs
	sys_entry["last_time"] = time
	var sys_metrics = ecs_data["systems"][system]["metrics"]
	if not sys_metrics:
		# Initialize metrics if not present
		sys_metrics = {"min_time": time, "max_time": time, "avg_time": time, "count": 1, "last_time": time}

	sys_metrics["min_time"] = min(sys_metrics["min_time"], time)
	sys_metrics["max_time"] = max(sys_metrics["max_time"], time)
	sys_metrics["count"] += 1
	sys_metrics["avg_time"] = (
		((sys_metrics["avg_time"] * (sys_metrics["count"] - 1)) + time) / sys_metrics["count"]
	)
	sys_metrics["last_time"] = time
	ecs_data["systems"][system]["metrics"] = sys_metrics

func system_last_run_data(system_id: int, system_name: String, last_run_data: Dictionary):
	var systems_data := get_or_create_dict(ecs_data, "systems")
	var sys_entry := get_or_create_dict(systems_data, system_id, default_system.duplicate())
	sys_entry["last_run_data"] = last_run_data
	# Update or create tree item
	if system_tree:
		var root = system_tree.get_root()
		if root == null:
			root = system_tree.create_item()
		# Try to find existing item by metadata matching system_id
		var existing: TreeItem = null
		var child = root.get_first_child()
		while child != null:
			if child.get_meta("system_id") == system_id:
				existing = child
				break
			child = child.get_next()
		if existing == null:
			existing = system_tree.create_item(root)
			existing.set_meta("system_id", system_id)
			existing.collapsed = true # Start collapsed
		# Set main system name
		existing.set_text(0, system_name)
		# Set active status in column 1
		var is_active = sys_entry.get("active", true)
		_update_system_active_display(existing, is_active)
		# Clear previous children to avoid stale data
		var prev_child = existing.get_first_child()
		while prev_child:
			var next_child = prev_child.get_next()
			existing.remove_child(prev_child)
			prev_child = next_child
		# Create nested rows for key info
		var exec_ms = last_run_data.get("execution_time_ms", 0.0)
		var ent_count = last_run_data.get("entity_count", null)
		var arch_count = last_run_data.get("archetype_count", null)
		var parallel = last_run_data.get("parallel", false)
		var nested_data := {
			"execution_time_ms": String.num(exec_ms, 3),
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
				sub_row.set_text(0, "subsystem[" + str(key) + "] entity_count: " + str(sub.get("entity_count", 0)))
		# Optionally store raw json in metadata for tooltip or future expansion
		existing.set_meta("last_run_data", last_run_data.duplicate())


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
				if child.get_meta("entity_id") == ent:
					entity_item = child
					break
				child = child.get_next()
			if entity_item:
				# Try to find existing component item to update instead of duplicating
				var existing_comp_item: TreeItem = null
				var comp_child = entity_item.get_first_child()
				while comp_child:
					if comp_child.get_meta("component_id") == comp:
						existing_comp_item = comp_child
						break
					comp_child = comp_child.get_next()
				if existing_comp_item:
					# Clear previous property rows
					var prev = existing_comp_item.get_first_child()
					while prev:
						var nxt = prev.get_next()
						existing_comp_item.remove_child(prev)
						prev = nxt
					# Update title/path in case script changed
					existing_comp_item.set_text(0, comp_path)
					existing_comp_item.set_meta("component_path", comp_path)
					_add_serialized_rows(existing_comp_item, final_data)
				else:
					_attach_component_to_entity_item(entity_item, ent, comp, comp_path, final_data)
			else:
				# Buffer component until entity_added arrives
				if not _pending_components.has(ent):
					_pending_components[ent] = []
				_pending_components[ent].append({"comp_id": comp, "comp_path": comp_path, "data": final_data})

func _attach_component_to_entity_item(entity_item: TreeItem, ent: int, comp: int, comp_path: String, final_data: Dictionary) -> void:
	var comp_item = entities_tree.create_item(entity_item)
	comp_item.set_text(0, comp_path)
	comp_item.set_meta("component_id", comp)
	comp_item.set_meta("component_path", comp_path)
	comp_item.collapsed = true # Start collapsed
	# Add property rows with recursive serialization
	_add_serialized_rows(comp_item, final_data)


func entity_component_removed(ent: int, comp: int):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("components"):
		entities[ent]["components"].erase(comp)
	if entities_tree and entities_tree.get_root():
		var entity_item: TreeItem = null
		var child = entities_tree.get_root().get_first_child()
		while child:
			if child.get_meta("entity_id") == ent:
				entity_item = child
				break
			child = child.get_next()
		if entity_item:
			var comp_child = entity_item.get_first_child()
			while comp_child:
				if comp_child.get_meta("component_id") == comp:
					entity_item.remove_child(comp_child)
					break
				comp_child = comp_child.get_next()


func entity_component_property_changed(
	ent: int, comp: int, property_name: String, old_value: Variant, new_value: Variant
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
			if child.get_meta("entity_id") == ent:
				entity_item = child
				break
			child = child.get_next()
		if entity_item:
			var comp_child = entity_item.get_first_child()
			while comp_child:
				if comp_child.get_meta("component_id") == comp:
					var prop_row = comp_child.get_first_child()
					var updated := false
					while prop_row:
						if prop_row.get_meta("property_name") == property_name:
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
			return "{...}" # expanded in children
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
				if child.get_meta("entity_id") == ent:
					entity_item = child
					break
				child = child.get_next()

			if entity_item:
				# Try to find existing relationship item to update
				var existing_rel_item: TreeItem = null
				var rel_child = entity_item.get_first_child()
				while rel_child:
					if rel_child.get_meta("relationship_id", -1) == rel:
						existing_rel_item = rel_child
						break
					rel_child = rel_child.get_next()

				if existing_rel_item:
					# Clear and rebuild
					var prev = existing_rel_item.get_first_child()
					while prev:
						var nxt = prev.get_next()
						existing_rel_item.remove_child(prev)
						prev = nxt
					_update_relationship_item(existing_rel_item, rel_data)
				else:
					# Create new relationship item
					var rel_item = entities_tree.create_item(entity_item)
					rel_item.set_meta("relationship_id", rel)
					rel_item.collapsed = true # Start collapsed
					_update_relationship_item(rel_item, rel_data)

func _update_relationship_item(rel_item: TreeItem, rel_data: Dictionary):
	# Format the relationship display
	var relation_type = rel_data.get("relation_type", "Unknown")
	var target_type = rel_data.get("target_type", "Unknown")

	# Build the title based on target type
	var title = "Relationship: " + relation_type + " -> "
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
			if child.get_meta("entity_id") == ent:
				entity_item = child
				break
			child = child.get_next()

		if entity_item:
			var rel_child = entity_item.get_first_child()
			while rel_child:
				if rel_child.get_meta("relationship_id", -1) == rel:
					entity_item.remove_child(rel_child)
					break
				rel_child = rel_child.get_next()
