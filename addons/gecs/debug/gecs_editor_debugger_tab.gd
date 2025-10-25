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

var ecs_data: Dictionary = {}
var default_system := {"path": "", "active": true, "metrics": {}, "group": ""}
var default_entity := {"path": "", "active": true, "components": {}, "relationships": {}}
var timer = 5
var active := false
var _pending_components: Dictionary = {} # ent_id -> Array[Dictionary] of pending component data
var _pinned_entities: Array[int] = [] # Array of entity IDs that are pinned
var _poll_timer := 0.5 # Poll pinned entities every 0.5 seconds
var _poll_accumulator := 0.0
var debugger_session: EditorDebuggerSession = null # Reference to the debugger session
var editor_interface: EditorInterface = null # Reference to editor interface for selecting nodes
var _always_poll_components := true # If true we use direct ObjectDB access instead of remote message
var _context_menu: PopupMenu = null # Reusable context menu
var _context_menu_entity_id: int = -1 # Track which entity the context menu is for

@onready var system_tree: Tree = %SystemsTree
@onready var entities_tree: Tree = %EntitiesTree


func _ready() -> void:
	if system_tree:
		# Single column; details will be nested children
		system_tree.columns = 1
	if entities_tree:
		entities_tree.columns = 1
		# Enable right-click selection
		entities_tree.allow_rmb_select = true
		# Set select mode to single (fixes selection issues)
		entities_tree.select_mode = Tree.SELECT_SINGLE

		# Connect tree item collapsed signal to handle on-demand polling (components only)
		if not entities_tree.item_collapsed.is_connected(_on_entities_tree_item_collapsed):
			entities_tree.item_collapsed.connect(_on_entities_tree_item_collapsed)

		# Connect for context menu on right-click
		if not entities_tree.item_mouse_selected.is_connected(_on_entity_tree_item_mouse_selected):
			entities_tree.item_mouse_selected.connect(_on_entity_tree_item_mouse_selected)

		# Connect for selection (left-click) to inspect entity in remote scene
		if not entities_tree.item_selected.is_connected(_on_entity_tree_item_selected):
			entities_tree.item_selected.connect(_on_entity_tree_item_selected)

	if entities_filter_line_edit and not entities_filter_line_edit.text_changed.is_connected(_on_entities_filter_changed):
		entities_filter_line_edit.text_changed.connect(_on_entities_filter_changed)
	if systems_filter_line_edit and not systems_filter_line_edit.text_changed.is_connected(_on_systems_filter_changed):
		systems_filter_line_edit.text_changed.connect(_on_systems_filter_changed)
	if collapse_all_btn and not collapse_all_btn.pressed.is_connected(_on_collapse_all_pressed):
		collapse_all_btn.pressed.connect(_on_collapse_all_pressed)
	if expand_all_btn and not expand_all_btn.pressed.is_connected(_on_expand_all_pressed):
		expand_all_btn.pressed.connect(_on_expand_all_pressed)
	if systems_collapse_all_btn and not systems_collapse_all_btn.pressed.is_connected(_on_systems_collapse_all_pressed):
		systems_collapse_all_btn.pressed.connect(_on_systems_collapse_all_pressed)
	if systems_expand_all_btn and not systems_expand_all_btn.pressed.is_connected(_on_systems_expand_all_pressed):
		systems_expand_all_btn.pressed.connect(_on_systems_expand_all_pressed)

	# Create reusable context menu
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func _process(delta: float) -> void:
	if not active:
		return
	timer -= delta
	if timer <= 0:
		timer = 5
		# Periodic prune & refresh of entity component properties (simple strategy)
		_refresh_entity_tree()
		_refresh_system_tree_filter()
		_refresh_entity_tree_filter()

	# Poll pinned entities more frequently
	_poll_accumulator += delta
	if _poll_accumulator >= _poll_timer:
		_poll_accumulator = 0.0
		_poll_pinned_entities()

# ---- Filters & Refresh Helpers ----
func _on_entities_filter_changed(new_text: String):
	_refresh_entity_tree_filter()

func _on_systems_filter_changed(new_text: String):
	_refresh_system_tree_filter()

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
		# If entity itself doesn't match, we check components for match before hiding
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

func _refresh_entity_tree():
	# Rebuild property rows if underlying ecs_data changed (removed keys)
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var entities_dict = ecs_data.get("entities", {})
	var entity_item = root.get_first_child()
	while entity_item:
		var ent_id = entity_item.get_meta("entity_id")
		if not entities_dict.has(ent_id):
			var next_entity = entity_item.get_next()
			root.remove_child(entity_item)
			entity_item = next_entity
			continue
		# For existing entity: prune removed components
		var comp_data: Dictionary = entities_dict[ent_id]["components"] if entities_dict[ent_id].has("components") else {}
		var comp_item = entity_item.get_first_child()
		while comp_item:
			var comp_id = comp_item.get_meta("component_id")
			if not comp_data.has(comp_id):
				var next_comp = comp_item.get_next()
				entity_item.remove_child(comp_item)
				comp_item = next_comp
				continue
			# Prune removed properties
			var stored_props: Dictionary = comp_data[comp_id]
			var prop_row = comp_item.get_first_child()
			while prop_row:
				var pname = prop_row.get_meta("property_name")
				if pname != null and not stored_props.has(pname):
					var next_prop = prop_row.get_next()
					comp_item.remove_child(prop_row)
					prop_row = next_prop
					continue
				# Update value text if changed
				if pname != null and str(stored_props[pname]) != prop_row.get_text(0).substr(pname.length() + 2):
					prop_row.set_text(0, pname + ": " + str(stored_props[pname]))
				prop_row = prop_row.get_next()
			comp_item = comp_item.get_next()
		entity_item = entity_item.get_next()

# ---- Expand/Collapse Helpers ----
func expand_all_entities():
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		item.collapsed = false
		var comp_item = item.get_first_child()
		while comp_item:
			comp_item.collapsed = false
			comp_item = comp_item.get_next()
		item = item.get_next()

func collapse_all_entities():
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		item.collapsed = true
		var comp_item = item.get_first_child()
		while comp_item:
			comp_item.collapsed = true
			comp_item = comp_item.get_next()
		item = item.get_next()

func expand_all_systems():
	if not system_tree:
		return
	var root = system_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		item.collapsed = false
		item = item.get_next()

func collapse_all_systems():
	if not system_tree:
		return
	var root = system_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		item.collapsed = true
		item = item.get_next()


# Helper to retrieve or create nested dictionary entries
func get_or_create_dict(dict: Dictionary, key, default_val = {}) -> Dictionary:
	if not dict.has(key):
		dict[key] = default_val
	return dict[key]


func world_init(world: int, world_path: NodePath):
	var world_dict = get_or_create_dict(ecs_data, "world")
	world_dict["id"] = world
	world_dict["path"] = world_path


func set_world(world: int, world_path: NodePath):
	var world_dict = get_or_create_dict(ecs_data, "world")
	if not world:
		world_dict["id"] = null
		world_dict["path"] = null
		return
	world_dict["id"] = world
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
		item.collapsed = true  # Start collapsed
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
		# Set main system name
		existing.set_text(0, system_name)
		# Clear previous children to avoid stale data
		var prev_child = existing.get_first_child()
		while prev_child:
			var next_child = prev_child.get_next()
			existing.remove_child(prev_child)
			prev_child = next_child
		# Display all data from last_run_data
		# Sort keys to show numeric subsystem indices last
		var regular_keys: Array = []
		var subsystem_keys: Array = []

		for key in last_run_data.keys():
			if typeof(key) == TYPE_INT:
				subsystem_keys.append(key)
			else:
				regular_keys.append(key)

		# Display regular string keys first
		for key in regular_keys:
			var value = last_run_data[key]
			var row = system_tree.create_item(existing)

			# Format specific known keys nicely
			if key == "execution_time_ms" and typeof(value) == TYPE_FLOAT:
				row.set_text(0, str(key) + ": " + String.num(value, 3))
			elif value is Dictionary:
				row.set_text(0, str(key) + ": {...}")
				_add_nested_dict_to_tree(row, value)
			elif value is Array:
				row.set_text(0, str(key) + ": [..." + str(value.size()) + "]")
				_add_nested_array_to_tree(row, value)
			else:
				row.set_text(0, str(key) + ": " + str(value))

		# Display subsystem details (numeric keys)
		for key in subsystem_keys:
			var sub = last_run_data[key]
			var sub_row = system_tree.create_item(existing)
			if sub is Dictionary:
				sub_row.set_text(0, "subsystem[" + str(key) + "]")
				_add_nested_dict_to_tree(sub_row, sub)
			else:
				sub_row.set_text(0, "subsystem[" + str(key) + "]: " + str(sub))
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
					existing_comp_item.set_text(0, "Component " + comp_path + " (#" + str(comp) + ")")
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
	comp_item.set_text(0, "Component " + comp_path + " (#" + str(comp) + ")")
	comp_item.set_meta("component_id", comp)
	comp_item.set_meta("component_path", comp_path)
	comp_item.collapsed = true  # Start collapsed
	# Add property rows with recursive serialization
	_add_serialized_rows(comp_item, final_data)


func entity_component_removed(
	ent: int,
	comp: int,
):
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

# Helper function to add nested dictionary to system tree
func _add_nested_dict_to_tree(parent_item: TreeItem, data: Dictionary):
	for key in data.keys():
		var value = data[key]
		var row = system_tree.create_item(parent_item)
		if value is Dictionary:
			row.set_text(0, str(key) + ": {...}")
			_add_nested_dict_to_tree(row, value)
		elif value is Array:
			row.set_text(0, str(key) + ": [..." + str(value.size()) + "]")
			_add_nested_array_to_tree(row, value)
		else:
			row.set_text(0, str(key) + ": " + str(value))

# Helper function to add nested array to system tree
func _add_nested_array_to_tree(parent_item: TreeItem, arr: Array):
	for i in range(arr.size()):
		var value = arr[i]
		var row = system_tree.create_item(parent_item)
		if value is Dictionary:
			row.set_text(0, "[" + str(i) + "]: {...}")
			_add_nested_dict_to_tree(row, value)
		elif value is Array:
			row.set_text(0, "[" + str(i) + "]: [..." + str(value.size()) + "]")
			_add_nested_array_to_tree(row, value)
		else:
			row.set_text(0, "[" + str(i) + "]: " + str(value))


func entity_relationship_added(ent: int, rel: int):
	var entities := get_or_create_dict(ecs_data, "entities")
	# Don't use default_entity when creating/retrieving an entity
	var entity := get_or_create_dict(entities, ent)
	var relationships := get_or_create_dict(entity, "relationships")
	relationships[rel] = {"some_data": "value"} # Placeholder for actual relationship data


func entity_relationship_removed(ent: int, rel: int):
	var entities = get_or_create_dict(ecs_data, "entities")
	if entities.has(ent) and entities[ent].has("relationships"):
		entities[ent]["relationships"].erase(rel)


# ---- Button Handlers ----
func _on_collapse_all_pressed():
	collapse_all_entities_only()

func _on_expand_all_pressed():
	expand_all_entities_only()

func _on_systems_collapse_all_pressed():
	collapse_all_systems()

func _on_systems_expand_all_pressed():
	expand_all_systems()

# ---- Entity Pinning ----
func pin_entity(ent_id: int):
	if not _pinned_entities.has(ent_id):
		_pinned_entities.append(ent_id)
		_reorder_pinned_entities()
		# Immediately poll this entity
		_poll_entity_components(ent_id)

func unpin_entity(ent_id: int):
	_pinned_entities.erase(ent_id)
	_reorder_pinned_entities()

func toggle_pin_entity(ent_id: int):
	if _pinned_entities.has(ent_id):
		unpin_entity(ent_id)
	else:
		pin_entity(ent_id)

func _reorder_pinned_entities():
	"""Move pinned entities to the top of the tree"""
	if not entities_tree or not entities_tree.get_root():
		return
	var root = entities_tree.get_root()

	# Collect all items
	var pinned_items: Array[TreeItem] = []
	var unpinned_items: Array[TreeItem] = []

	var item = root.get_first_child()
	while item:
		var next_item = item.get_next()
		var ent_id = item.get_meta("entity_id")
		if _pinned_entities.has(ent_id):
			pinned_items.append(item)
			# Update visual to show pinned status
			var text = item.get_text(0)
			if not text.begins_with("📌 "):
				item.set_text(0, "📌 " + text)
		else:
			unpinned_items.append(item)
			# Remove pin icon if present
			var text = item.get_text(0)
			if text.begins_with("📌 "):
				item.set_text(0, text.substr(3))
		item = next_item

	# Remove all items
	for itm in pinned_items + unpinned_items:
		root.remove_child(itm)

	# Re-add in order: pinned first, then unpinned
	for itm in pinned_items:
		root.add_child(itm)
	for itm in unpinned_items:
		root.add_child(itm)

# ---- Collapse/Expand Entities Only (not components) ----
func expand_all_entities_only():
	"""Expand all entities but keep their components collapsed"""
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		item.collapsed = false
		item = item.get_next()

func collapse_all_entities_only():
	"""Collapse all entities"""
	if not entities_tree:
		return
	var root = entities_tree.get_root()
	if root == null:
		return
	var item = root.get_first_child()
	while item:
		item.collapsed = true
		item = item.get_next()

# ---- On-Demand Component Polling ----
func _on_entities_tree_item_collapsed(item: TreeItem):
	"""Called when a tree item is expanded or collapsed.
	If it's a component item (has component_id) and is being expanded we poll fresh data for that component only.
	If it's an entity item we do nothing (components expand individually)."""
	if item.collapsed:
		return
	# Expanded
	if item.has_meta("component_id"):
		_poll_single_component_item(item)
	elif item.has_meta("entity_id"):
		# Optionally: could lazy-create component items here if we chose not to create on add.
		pass

func _poll_entity_components(ent_id: int):
	"""Poll all components of an entity (direct ObjectDB access)."""
	if not entities_tree or not entities_tree.get_root():
		return
	var root = entities_tree.get_root()
	var entity_item = root.get_first_child()
	while entity_item:
		if entity_item.get_meta("entity_id") == ent_id:
			# Iterate component items
			var comp_item = entity_item.get_first_child()
			while comp_item:
				_poll_single_component_item(comp_item)
				comp_item = comp_item.get_next()
			break
		entity_item = entity_item.get_next()

func _poll_single_component_item(comp_item: TreeItem):
	"""Poll one component TreeItem and update its property rows."""
	if not comp_item.has_meta("component_id"):
		return
	var comp_id = comp_item.get_meta("component_id")
	# Godot 4: use built-in instance_from_id to resolve instance ID
	var comp_obj = instance_from_id(comp_id)
	if comp_obj == null:
		return
	# Re-serialize latest data
	var latest: Dictionary = {}
	if comp_obj.has_method("serialize"):
		latest = comp_obj.serialize()
	# Update ecs_data mirror
	var ent_id = -1
	var parent_entity = comp_item.get_parent()
	if parent_entity and parent_entity.has_meta("entity_id"):
		ent_id = parent_entity.get_meta("entity_id")
		var entities := get_or_create_dict(ecs_data, "entities")
		var ent_dict := get_or_create_dict(entities, ent_id)
		var comps := get_or_create_dict(ent_dict, "components")
		comps[comp_id] = latest
	# Clear existing property rows
	var prev = comp_item.get_first_child()
	while prev:
		var nxt = prev.get_next()
		comp_item.remove_child(prev)
		prev = nxt
	# Rebuild
	_add_serialized_rows(comp_item, latest)

func _poll_pinned_entities():
	"""Poll all pinned entities for updates"""
	for ent_id in _pinned_entities:
		_poll_entity_components(ent_id)

# ---- Entity Selection for Remote Inspection ----
func _on_entity_tree_item_selected():
	"""Handle left-click on entity tree items to inspect in remote scene"""
	var selected = entities_tree.get_selected()
	if not selected:
		return

	# Check if it's an entity item (not a component)
	if selected.has_meta("entity_id"):
		var ent_id = selected.get_meta("entity_id")
		print("GECS: Entity selected in GECS tab, will inspect entity: ", ent_id)
		# Don't deselect - let both trees have selections
		_inspect_remote_entity(ent_id)

func _inspect_remote_entity(ent_id: int):
	"""Request the debugger to inspect/select the entity in the remote scene tree"""
	if not editor_interface:
		return

	# Get entity path from our stored data
	var entities = ecs_data.get("entities", {})
	if not entities.has(ent_id):
		return

	var entity_data = entities[ent_id]
	var entity_path = entity_data.get("path", NodePath())

	if entity_path.is_empty():
		return

	# Try to find and select the node in the editor's Remote scene tree
	# The Remote scene tree is managed by EditorDebuggerTree
	# We need to access it through the editor interface
	print("GECS: Attempting to select entity in Remote scene tree: ", entity_path)
	print("  Entity ID: ", ent_id)

	# Get the base control and search for the Remote scene tree
	var base = editor_interface.get_base_control()
	_find_and_select_in_remote_scene_tree(base, ent_id, entity_path)

func _find_and_select_in_remote_scene_tree(node: Node, obj_id: int, path: NodePath) -> bool:
	"""Recursively find the EditorDebuggerTree (Remote scene tree) and select the node"""
	# Look for the EditorDebuggerTree class
	if node.get_class() == "EditorDebuggerTree" or node.name == "RemoteTree":
		# EditorDebuggerTree is a Tree - try to find and select the item
		if node is Tree:
			var tree = node as Tree

			# Monitor when selection changes
			if not tree.is_connected("item_selected", _on_remote_tree_selection_changed):
				tree.item_selected.connect(_on_remote_tree_selection_changed.bind(tree, path))
				print("  Connected to remote tree selection signal")

			var root = tree.get_root()
			if root:
				var found_item = _find_tree_item_by_metadata(root, "node_path", path)
				if found_item:
					print("  Found item, expanding parents...")
					# Ensure it's visible by uncollapsing parents first
					var parent = found_item.get_parent()
					while parent:
						parent.collapsed = false
						parent = parent.get_parent()

					# Select and focus the item
					print("  Selecting item...")
					print("  Selection BEFORE: ", tree.get_selected())
					found_item.select(0)
					print("  Selection AFTER select(): ", tree.get_selected())
					tree.scroll_to_item(found_item)
					print("  Selection AFTER scroll: ", tree.get_selected())
					return true
		return false

	# Recursively check children
	for child in node.get_children():
		if _find_and_select_in_remote_scene_tree(child, obj_id, path):
			return true

	return false

func _on_remote_tree_selection_changed(tree: Tree, expected_path: NodePath):
	var selected = tree.get_selected()
	if selected:
		var selected_path = selected.get_meta("node_path") if selected.has_meta("node_path") else ""
		print("  >> REMOTE TREE SELECTION CHANGED: ", selected_path, " (expected: ", expected_path, ")")
	else:
		print("  >> REMOTE TREE SELECTION CLEARED (expected: ", expected_path, ")")

func _find_tree_item_by_metadata(item: TreeItem, meta_key: String, meta_value) -> TreeItem:
	"""Recursively search tree items for matching metadata"""
	if item.has_meta(meta_key):
		var item_meta = item.get_meta(meta_key)
		# Compare NodePaths as strings
		if meta_key == "node_path":
			if str(item_meta) == str(meta_value):
				return item
		elif item_meta == meta_value:
			return item

	# Check children
	var child = item.get_first_child()
	while child:
		var result = _find_tree_item_by_metadata(child, meta_key, meta_value)
		if result:
			return result
		child = child.get_next()

	return null

# ---- Context Menu for Pinning ----
func _on_entity_tree_item_mouse_selected(position: Vector2, mouse_button_index: int):
	"""Handle right-click on entity tree items"""
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return

	var selected = entities_tree.get_selected()
	if not selected or not selected.has_meta("entity_id"):
		return

	var ent_id = selected.get_meta("entity_id")

	# Store the entity ID for the context menu handler
	_context_menu_entity_id = ent_id

	# Clear and rebuild menu items
	_context_menu.clear()

	if _pinned_entities.has(ent_id):
		_context_menu.add_item("Unpin Entity", 0)
	else:
		_context_menu.add_item("Pin Entity", 0)

	_context_menu.add_item("Refresh Components", 1)
	_context_menu.add_item("Inspect in Remote Scene", 2)

	# Position the menu at the mouse cursor
	# The position parameter from the signal is already in tree-local coordinates
	var global_pos = entities_tree.get_screen_position() + position
	_context_menu.position = global_pos
	_context_menu.popup()

func _on_context_menu_id_pressed(id: int):
	"""Handle context menu item selection"""
	if id == 0:
		toggle_pin_entity(_context_menu_entity_id)
	elif id == 1:
		_poll_entity_components(_context_menu_entity_id)
	elif id == 2:
		_inspect_remote_entity(_context_menu_entity_id)

func set_debugger_session(session: EditorDebuggerSession):
	"""Called by the debugger plugin to set the session reference"""
	debugger_session = session

func set_editor_interface(interface: EditorInterface):
	"""Called by the debugger plugin to set the editor interface reference"""
	editor_interface = interface
	print("GECS Debug: Editor interface set: ", interface)

func clear_all_data():
	"""Clear all debug data and trees when starting a new debug session"""
	# Clear data dictionary
	ecs_data.clear()
	_pending_components.clear()
	_pinned_entities.clear()

	# Clear system tree
	if system_tree:
		system_tree.clear()
		var root = system_tree.create_item()

	# Clear entities tree
	if entities_tree:
		entities_tree.clear()
		var root = entities_tree.create_item()
