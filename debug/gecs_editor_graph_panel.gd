@tool
## Graph view of the GECS debugger tab, hosted by a [GECSEditorGraphWindow]:
## watched entities as GraphNodes (their components listed inside),
## relationships as connections, and non-entity relationship targets (archetype
## scripts, component instances, the wildcard) as small nodes. Fed by
## [code]gecs:graph_state[/code] payloads for its [member graph_id]
## (GECSGraphState.build).
##
## "Show live" makes the tab pull a fresh payload at its poll rate while the
## game runs; while paused the stepper pushes one after every step, so the graph
## follows a step-by-step session on its own. Node positions persist across
## updates; only new nodes get placed (next to a connected node) and stale
## nodes are removed.
class_name GECSEditorGraphPanel
extends VBoxContainer

## Activation is separate from GraphEdit selection and dragging.
signal entity_activated(entity: Dictionary)

const ICON_ENTITY := "📦"
const ICON_COMPONENT := "🔧"
const ICON_RELATIONSHIP := "🔗"
const COLOR_IN := Color(0.55, 0.75, 1.0)
const COLOR_OUT := Color(1.0, 0.8, 0.45)
const NODE_SPACING := Vector2(340, 40)
const MAX_DATA_CHARS := 60

## Editor -> game sender: [code]Callable(message: String, data: Array) -> bool[/code].
var send: Callable = Callable()
## Returns the entity instance ids currently selected in the tab's entity tree.
var selected_entities_provider: Callable = Callable()
## Id of the game-side graph this view mirrors (GECSStepper.graphs key).
var graph_id := 0

## Watched entity instance ids as reported by the last payload.
var watch_ids: Array = []
## Mirrors the stepper's paused flag (live pulls stop while paused).
var paused := false
## The last applied payload.
var last_graph: Dictionary = {}

var show_live_check: CheckButton
var depth_spin: SpinBox
var add_selected_btn: Button
var arrange_btn: Button
var info_label: Label
var graph: GraphEdit

var _nodes: Dictionary = {}  # key -> GraphNode
var _edge_ports: Dictionary = {}  # edge key -> [from_name, from_port, to_name, to_port]
var _highlighted: Array = []
var _highlight_style: StyleBoxFlat


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if graph != null:
		return
	var bar := HBoxContainer.new()
	add_child(bar)
	var title := Label.new()
	title.text = "Graph"
	bar.add_child(title)
	show_live_check = CheckButton.new()
	show_live_check.text = "Show live"
	show_live_check.tooltip_text = "Refresh the watched entities at the entity poll rate while the game runs. While paused, every step refreshes the graph."
	bar.add_child(show_live_check)
	var depth_label := Label.new()
	depth_label.text = "Depth:"
	bar.add_child(depth_label)
	depth_spin = SpinBox.new()
	depth_spin.min_value = 0
	depth_spin.max_value = 3
	depth_spin.value = 0
	depth_spin.custom_minimum_size = Vector2(56, 0)
	depth_spin.tooltip_text = "Relationship hops to include around the watched entities (0 = watched entities plus stubs for their neighbours)."
	depth_spin.value_changed.connect(_on_depth_changed)
	bar.add_child(depth_spin)
	add_selected_btn = Button.new()
	add_selected_btn.text = "Add selected"
	add_selected_btn.tooltip_text = "Add the entities selected in the entity tree to this graph."
	add_selected_btn.pressed.connect(_on_add_selected)
	bar.add_child(add_selected_btn)
	arrange_btn = Button.new()
	arrange_btn.text = "Arrange"
	arrange_btn.tooltip_text = "Auto-layout the graph."
	arrange_btn.pressed.connect(_on_arrange)
	bar.add_child(arrange_btn)
	info_label = Label.new()
	info_label.text = "Waiting for the game..."
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.clip_text = true
	bar.add_child(info_label)

	graph = GraphEdit.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(0, 160)
	graph.right_disconnects = false
	graph.minimap_enabled = false
	add_child(graph)

	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = Color(0.85, 0.45, 0.1)
	_highlight_style.set_corner_radius_all(4)
	_highlight_style.content_margin_left = 8
	_highlight_style.content_margin_right = 8
	_highlight_style.content_margin_top = 4
	_highlight_style.content_margin_bottom = 4


#region Incoming


func set_paused(value: bool) -> void:
	paused = value


## True while the tab should pull a fresh payload at its poll rate.
func wants_live_pull() -> bool:
	return (
		show_live_check != null
		and show_live_check.button_pressed
		and not watch_ids.is_empty()
		and not paused
	)


## Apply a [code]gecs:graph_state[/code] payload: update / create / remove
## nodes, rebuild connections, keep existing node positions.
func apply_graph(step_id: int, payload: Dictionary) -> void:
	last_graph = payload
	watch_ids = payload.get("watched", []).duplicate()
	if graph == null:
		return
	var nodes: Array = payload.get("nodes", [])
	var edges: Array = payload.get("edges", [])
	var was_empty := _nodes.is_empty()
	var out_by_source: Dictionary = {}
	for edge in edges:
		var from_key: String = edge.get("from", "")
		if not out_by_source.has(from_key):
			out_by_source[from_key] = []
		out_by_source[from_key].append(edge)
	var seen: Dictionary = {}
	for node in nodes:
		var key: String = node.get("key", "")
		if key == "":
			continue
		seen[key] = true
		var gn: GraphNode = _nodes.get(key)
		if gn == null:
			gn = GraphNode.new()
			gn.name = _node_name(key)
			gn.set_meta("key", key)
			gn.gui_input.connect(_node_input.bind(key))
			gn.resizable = false
			graph.add_child(gn)
			_nodes[key] = gn
			gn.position_offset = _initial_position(key, edges)
		_fill_node(gn, node, out_by_source.get(key, []))
	for key in _nodes.keys():
		if not seen.has(key):
			var stale: GraphNode = _nodes[key]
			graph.remove_child(stale)
			stale.queue_free()
			_nodes.erase(key)
	graph.clear_connections()
	_edge_ports.clear()
	for edge in edges:
		var from_gn: GraphNode = _nodes.get(edge.get("from", ""))
		var to_gn: GraphNode = _nodes.get(edge.get("to", ""))
		if from_gn == null or to_gn == null:
			continue
		var ports: Dictionary = from_gn.get_meta("edge_ports", {})
		var port: int = int(ports.get(edge.get("key", ""), -1))
		if port < 0:
			continue
		graph.connect_node(from_gn.name, port, to_gn.name, 0)
		_edge_ports[edge.get("key", "")] = [from_gn.name, port, to_gn.name, 0]
	if info_label:
		info_label.text = "%d nodes, %d edges (step %d)" % [nodes.size(), edges.size(), step_id]
	if was_empty and not _nodes.is_empty():
		graph.call_deferred("arrange_nodes")


## Mark the entities touched by the last step and the relationships it added.
## Previous marks are cleared first.
func highlight(touched_entity_ids: Array, added_edge_keys: Array) -> void:
	for key in _highlighted:
		var old: GraphNode = _nodes.get(key)
		if old != null:
			old.remove_theme_stylebox_override("titlebar")
	_highlighted = []
	for iid in touched_entity_ids:
		var key := "e:%d" % int(iid)
		var gn: GraphNode = _nodes.get(key)
		if gn != null:
			gn.add_theme_stylebox_override("titlebar", _highlight_style)
			_highlighted.append(key)
	if graph == null:
		return
	for edge_key in added_edge_keys:
		var ports = _edge_ports.get(edge_key)
		if ports != null:
			graph.set_connection_activity(ports[0], ports[1], ports[2], ports[3], 1.0)


func clear() -> void:
	watch_ids = []
	last_graph = {}
	_edge_ports.clear()
	_highlighted = []
	if graph:
		graph.clear_connections()
		for gn in _nodes.values():
			graph.remove_child(gn)
			gn.queue_free()
	_nodes.clear()
	if info_label:
		info_label.text = "Waiting for the game..."


#endregion Incoming

#region Outgoing


## Merge [param entity_ids] into the watch set and refresh.
func watch(entity_ids: Array) -> void:
	var ids: Array = watch_ids.duplicate()
	for iid in entity_ids:
		if not ids.has(iid):
			ids.append(iid)
	_send_watch(ids)


func _on_add_selected() -> void:
	var ids: Array = selected_entities_provider.call() if selected_entities_provider.is_valid() else []
	watch(ids)


func _on_depth_changed(_value: float) -> void:
	if not watch_ids.is_empty():
		_send_watch(watch_ids)


func _on_arrange() -> void:
	if graph:
		graph.arrange_nodes()


func _send_watch(ids: Array) -> void:
	if send.is_valid():
		send.call("gecs:graph_watch", [graph_id, ids, int(depth_spin.value) if depth_spin else 0])


#endregion Outgoing

#region Node rendering


static func _node_name(key: String) -> String:
	# GraphNode names cannot contain ':' '/' '.' '@' '%'; hash the key instead.
	return "gn_%d" % absi(key.hash())


func _initial_position(key: String, edges: Array) -> Vector2:
	for edge in edges:
		if edge.get("from", "") == key:
			var other: GraphNode = _nodes.get(edge.get("to", ""))
			if other != null and other.get_meta("key", "") != key:
				return other.position_offset - Vector2(NODE_SPACING.x, 0)
		elif edge.get("to", "") == key:
			var other: GraphNode = _nodes.get(edge.get("from", ""))
			if other != null and other.get_meta("key", "") != key:
				return other.position_offset + Vector2(NODE_SPACING.x, NODE_SPACING.y * (_nodes.size() % 5))
	var count := _nodes.size() - 1
	return Vector2(40 + (count % 3) * NODE_SPACING.x, 40 + (count / 3) * 220)


func _node_input(event: InputEvent, key: String) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or not event.double_click: return
	for node in last_graph.get("nodes", []):
		if node.get("key") == key and node.get("kind", "entity") == "entity":
			entity_activated.emit(node.duplicate(true))
			return


func _fill_node(gn: GraphNode, node: Dictionary, out_edges: Array) -> void:
	for child in gn.get_children():
		gn.remove_child(child)
		child.queue_free()
	gn.clear_all_slots()
	var kind: String = node.get("kind", "entity")
	gn.set_meta("kind", kind)
	var edge_ports: Dictionary = {}
	match kind:
		"entity":
			var title := "%s %s" % [ICON_ENTITY, node.get("name", "")]
			if bool(node.get("watched", false)):
				title += "  [watched]"
			gn.title = title
			var header := Label.new()
			var header_text := "#%d" % int(node.get("id", 0))
			if not bool(node.get("enabled", true)):
				header_text += "  (disabled)"
			if int(node.get("dangling", 0)) > 0:
				header_text += "  %d dangling" % int(node.get("dangling", 0))
			if bool(node.get("stub", false)):
				header_text += "  (outside the watch set)"
			header.text = header_text
			gn.add_child(header)
			gn.set_slot(0, true, 0, COLOR_IN, false, 0, COLOR_OUT)
			for comp in node.get("components", []):
				var comp_label := Label.new()
				comp_label.text = "%s %s  %s" % [ICON_COMPONENT, comp.get("type", ""), _compact(comp.get("data", {}))]
				comp_label.tooltip_text = str(comp.get("data", {}))
				gn.add_child(comp_label)
		"script":
			gn.title = "Archetype %s" % node.get("label", "")
			var l := Label.new()
			l.text = "any entity of this type"
			gn.add_child(l)
			gn.set_slot(0, true, 0, COLOR_IN, false, 0, COLOR_OUT)
		"component":
			gn.title = "%s %s" % [ICON_COMPONENT, node.get("label", "")]
			var l := Label.new()
			l.text = _compact(node.get("data", {}))
			gn.add_child(l)
			gn.set_slot(0, true, 0, COLOR_IN, false, 0, COLOR_OUT)
		_:
			gn.title = "* (wildcard)"
			var l := Label.new()
			l.text = "any target"
			gn.add_child(l)
			gn.set_slot(0, true, 0, COLOR_IN, false, 0, COLOR_OUT)
	var port := 0
	for edge in out_edges:
		var edge_label := Label.new()
		edge_label.text = "%s %s -> %s" % [ICON_RELATIONSHIP, _short(str(edge.get("relation_type", ""))), _target_text(edge)]
		var rel_data = edge.get("relation_data", {})
		if rel_data is Dictionary and not rel_data.is_empty():
			edge_label.tooltip_text = str(rel_data)
		gn.add_child(edge_label)
		gn.set_slot(gn.get_child_count() - 1, false, 0, COLOR_IN, true, 0, COLOR_OUT)
		edge_ports[edge.get("key", "")] = port
		port += 1
	gn.set_meta("edge_ports", edge_ports)


static func _short(type_name: String) -> String:
	if type_name.begins_with("res://"):
		return type_name.get_file().get_basename()
	return type_name


func _target_text(edge: Dictionary) -> String:
	var target_type: String = str(edge.get("target_type", ""))
	var target_data = edge.get("target_data", {})
	match target_type:
		"Entity":
			var to_gn: GraphNode = _nodes.get(edge.get("to", ""))
			if to_gn != null:
				return to_gn.title.trim_prefix(ICON_ENTITY + " ").replace("  [watched]", "")
			return str(target_data.get("path", "")).get_file()
		"Component":
			return "Component " + _short(str(target_data.get("type", "")))
		"Archetype":
			return "Archetype " + _short(str(target_data.get("script_path", "")))
		"null":
			return "*"
	return target_type


static func _compact(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	var parts := []
	for key in data:
		parts.append("%s=%s" % [key, data[key]])
	var text := ", ".join(parts)
	if text.length() > MAX_DATA_CHARS:
		text = text.left(MAX_DATA_CHARS) + "..."
	return text


#endregion Node rendering
