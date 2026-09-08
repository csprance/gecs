@tool
## Step debugger pane of the GECS debugger tab: transport buttons, the step
## set, the status line, and a Step log / Breakpoints tab pair. Kept short so
## the bottom panel's minimum height stays small.
##
## Talks to the game only through [member send] (injected by the tab, wraps
## [method GECSEditorDebuggerTab.send_to_game]) and reports incoming state and
## logs through signals so the tab can mark its own entity / system trees.
## Builds its controls in code so the debugger scene stays small.
class_name GECSEditorStepPanel
extends VBoxContainer

## Emitted after a [code]gecs:step_state[/code] payload was applied.
signal state_applied(state: Dictionary)
## Emitted after a [code]gecs:step_log[/code] entry was appended.
signal log_appended(log: Dictionary)

const MAX_LOG_ENTRIES := 200
const KIND_LABELS := ["Frame", "Group", "System", "Archetype", "Entity"]
const KIND_TOOLTIPS := [
	"Run one main-loop iteration (every process group called in it).",
	"Run the rest of the current process group, including its PER_GROUP flush.",
	"Run the next system (including its PER_SYSTEM command flush).",
	"Run the next process() call of the current system (one archetype).",
	"Like Archetype, but each entity in the step set runs as its own process() call.",
]
const COLOR_BREAK := Color(1.0, 0.45, 0.35)
const COLOR_EXTERNAL := Color(0.65, 0.65, 0.7)
const COLOR_SWEEP := Color(0.95, 0.75, 0.3)

## Editor -> game sender: [code]Callable(message: String, data: Array) -> bool[/code].
var send: Callable = Callable()
## Returns the entity instance ids currently selected in the tab's entity tree.
var selected_entities_provider: Callable = Callable()

## Last applied stepper state (see GECSStepper.state()).
var state: Dictionary = {}
var paused := false
## Retained step logs, oldest first (capped at MAX_LOG_ENTRIES).
var logs: Array = []

var pause_btn: Button
var resume_btn: Button
var step_buttons: Array = []
var count_spin: SpinBox
var step_set_label: Label
var use_selected_btn: Button
var clear_set_btn: Button
var sweep_check: CheckBox
var status_label: Label
var tabs: TabContainer
var breakpoints_tree: Tree
var clear_breakpoints_btn: Button
var log_tree: Tree
var clear_log_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if pause_btn != null:
		return
	var transport := HBoxContainer.new()
	add_child(transport)
	pause_btn = _button(transport, "Pause", "Pause ECS processing. The scene keeps running; only systems stop.", _on_pause)
	resume_btn = _button(transport, "Resume", "Resume live processing (a partially stepped system is finished first).", _on_resume)
	transport.add_child(VSeparator.new())
	var step_label := Label.new()
	step_label.text = "Step:"
	transport.add_child(step_label)
	for kind in KIND_LABELS.size():
		step_buttons.append(_button(transport, KIND_LABELS[kind], KIND_TOOLTIPS[kind], _on_step.bind(kind)))
	count_spin = SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 1000
	count_spin.value = 1
	count_spin.custom_minimum_size = Vector2(64, 0)
	count_spin.tooltip_text = "Steps per click."
	transport.add_child(count_spin)

	var set_row := HBoxContainer.new()
	add_child(set_row)
	step_set_label = Label.new()
	step_set_label.text = "Step set: 0"
	step_set_label.tooltip_text = "Entities that run as their own process() call under Entity stepping."
	set_row.add_child(step_set_label)
	use_selected_btn = _button(set_row, "Use selected entities", "Step through the entities selected in the entity tree.", _on_use_selected)
	clear_set_btn = _button(set_row, "Clear set", "Empty the step set (Entity stepping then behaves like Archetype).", _on_clear_set)
	sweep_check = CheckBox.new()
	sweep_check.text = "Sweep"
	sweep_check.button_pressed = true
	sweep_check.tooltip_text = "After every step, diff every component property to catch writes made without an emitting setter (sweep_set ops)."
	sweep_check.toggled.connect(_on_sweep_toggled)
	set_row.add_child(sweep_check)

	status_label = Label.new()
	status_label.text = "Live"
	status_label.clip_text = true
	status_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(status_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	var log_box := VBoxContainer.new()
	log_box.name = "Step log"
	tabs.add_child(log_box)
	var log_header := HBoxContainer.new()
	log_box.add_child(log_header)
	var log_hint := Label.new()
	log_hint.text = "One row per step, break or external change; expand it for the ops."
	log_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_hint.clip_text = true
	log_header.add_child(log_hint)
	clear_log_btn = _button(log_header, "Clear log", "Forget the retained step entries.", _on_clear_log)
	log_tree = Tree.new()
	log_tree.columns = 5
	log_tree.hide_root = true
	log_tree.column_titles_visible = true
	log_tree.set_column_title(0, "#")
	log_tree.set_column_title(1, "Step / op")
	log_tree.set_column_title(2, "Kind / target")
	log_tree.set_column_title(3, "Ops / detail")
	log_tree.set_column_title(4, "ms / cause")
	log_tree.set_column_expand(0, false)
	log_tree.set_column_custom_minimum_width(0, 44)
	log_tree.set_column_expand(1, true)
	log_tree.set_column_expand(2, true)
	log_tree.set_column_expand(3, true)
	log_tree.set_column_expand(4, true)
	for c in 5:
		log_tree.set_column_clip_content(c, true)
	log_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_tree.create_item()
	log_box.add_child(log_tree)

	var bp_box := VBoxContainer.new()
	bp_box.name = "Breakpoints"
	tabs.add_child(bp_box)
	var bp_header := HBoxContainer.new()
	bp_box.add_child(bp_header)
	var bp_hint := Label.new()
	bp_hint.text = "Set from the entity, component and system context menus or the BP column."
	bp_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_hint.clip_text = true
	bp_header.add_child(bp_hint)
	clear_breakpoints_btn = _button(bp_header, "Clear all", "Remove every breakpoint.", _on_clear_breakpoints)
	breakpoints_tree = Tree.new()
	breakpoints_tree.columns = 3
	breakpoints_tree.hide_root = true
	breakpoints_tree.column_titles_visible = true
	breakpoints_tree.set_column_title(0, "On")
	breakpoints_tree.set_column_title(1, "Breakpoint")
	breakpoints_tree.set_column_title(2, "Hits")
	breakpoints_tree.set_column_expand(0, false)
	breakpoints_tree.set_column_custom_minimum_width(0, 36)
	breakpoints_tree.set_column_expand(2, false)
	breakpoints_tree.set_column_custom_minimum_width(2, 48)
	breakpoints_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	breakpoints_tree.create_item()
	breakpoints_tree.item_edited.connect(_on_bp_item_edited)
	breakpoints_tree.button_clicked.connect(_on_bp_button_clicked)
	bp_box.add_child(breakpoints_tree)
	_update_buttons()


func _button(parent: Control, text: String, tooltip: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


#region Incoming messages


## Apply a [code]gecs:step_state[/code] payload.
func apply_state(new_state: Dictionary) -> void:
	state = new_state
	paused = bool(state.get("paused", false))
	if step_set_label:
		step_set_label.text = "Step set: %d" % state.get("step_entities", []).size()
	if sweep_check:
		sweep_check.set_pressed_no_signal(bool(state.get("sweep_enabled", true)))
	if status_label:
		status_label.text = _status_text(state)
		status_label.tooltip_text = status_label.text
	_rebuild_breakpoints(state.get("breakpoints", []))
	_update_buttons()
	state_applied.emit(state)


## Append a [code]gecs:step_log[/code] entry (a step, a breakpoint hit or the
## external bucket) with one child row per journaled op.
func append_log(log: Dictionary) -> void:
	logs.append(log)
	if logs.size() > MAX_LOG_ENTRIES:
		logs.pop_front()
		if log_tree and log_tree.get_root():
			var first := log_tree.get_root().get_first_child()
			if first:
				first.free()
	if log_tree:
		var root := log_tree.get_root()
		if root == null:
			root = log_tree.create_item()
		var row := log_tree.create_item(root)
		row.collapsed = true
		row.set_meta("log", log)
		var kind_name: String = str(log.get("kind_name", ""))
		var ops: Array = log.get("ops", [])
		row.set_text(0, str(log.get("step_id", 0)))
		row.set_text(1, str(log.get("label", "")))
		row.set_text(2, kind_name)
		var op_text := str(log.get("op_count", ops.size()))
		if log.get("truncated", false):
			op_text += "+"
		row.set_text(3, op_text)
		row.set_text(4, String.num(float(log.get("ms", 0.0)), 3))
		var systems: Array = log.get("systems", [])
		if systems.size() > 1:
			row.set_tooltip_text(1, "Systems: " + ", ".join(systems))
		if kind_name == "break":
			for c in 5:
				row.set_custom_color(c, COLOR_BREAK)
		elif kind_name == "external":
			for c in 5:
				row.set_custom_color(c, COLOR_EXTERNAL)
		var skipped: Array = log.get("skipped", [])
		if not skipped.is_empty():
			var skip_row := log_tree.create_item(row)
			skip_row.set_text(1, "skipped")
			skip_row.set_text(2, ", ".join(skipped))
			for c in 5:
				skip_row.set_custom_color(c, COLOR_EXTERNAL)
		var brk: Dictionary = log.get("break_info", {})
		if not brk.is_empty():
			var brk_row := log_tree.create_item(row)
			brk_row.set_text(1, "breakpoint hit")
			brk_row.set_text(2, str(brk.get("label", "")))
			var who := str(brk.get("op", ""))
			if brk.get("entity_name", "") != "":
				who += " on %s" % brk.get("entity_name")
			brk_row.set_text(3, who)
			brk_row.set_text(4, str(brk.get("system", "")))
			for c in 5:
				brk_row.set_custom_color(c, COLOR_BREAK)
		for op in ops:
			var cells := _format_op(op)
			var op_row := log_tree.create_item(row)
			for c in cells.size():
				op_row.set_text(c + 1, cells[c])
				op_row.set_tooltip_text(c + 1, cells[c])
			if op[0] == GECSStepper.Op.SWEEP_SET:
				for c in 5:
					op_row.set_custom_color(c, COLOR_SWEEP)
		log_tree.scroll_to_item(row)
	log_appended.emit(log)


func clear() -> void:
	state = {}
	paused = false
	logs = []
	if log_tree:
		log_tree.clear()
		log_tree.create_item()
	if breakpoints_tree:
		breakpoints_tree.clear()
		breakpoints_tree.create_item()
	if step_set_label:
		step_set_label.text = "Step set: 0"
	if status_label:
		status_label.text = "Live"
		status_label.tooltip_text = ""
	_set_breakpoints_title(0)
	_update_buttons()


#endregion Incoming messages

#region Outgoing commands (also used by the tab's context menus)


## Add a breakpoint spec (see GECSStepper.add_breakpoint) in the game.
func add_breakpoint(spec: Dictionary) -> void:
	_send("gecs:breakpoint_add", [spec])


## Merge [param entity_ids] into the step set.
func add_to_step_set(entity_ids: Array) -> void:
	var ids: Array = state.get("step_entities", []).duplicate()
	for iid in entity_ids:
		if not ids.has(iid):
			ids.append(iid)
	_send("gecs:step_set_entities", [ids])


func _on_pause() -> void:
	_send("gecs:step_pause", [])


func _on_resume() -> void:
	_send("gecs:step_resume", [])


func _on_step(kind: int) -> void:
	_send("gecs:step", [kind, int(count_spin.value) if count_spin else 1])


func _on_use_selected() -> void:
	var ids: Array = selected_entities_provider.call() if selected_entities_provider.is_valid() else []
	_send("gecs:step_set_entities", [ids])


func _on_clear_set() -> void:
	_send("gecs:step_set_entities", [[]])


func _on_sweep_toggled(pressed: bool) -> void:
	_send("gecs:step_set_sweep", [pressed])


func _on_clear_breakpoints() -> void:
	_send("gecs:breakpoint_clear", [])


func _on_bp_item_edited() -> void:
	if not breakpoints_tree or breakpoints_tree.get_edited_column() != 0:
		return
	var item := breakpoints_tree.get_edited()
	if item == null:
		return
	_send("gecs:breakpoint_set_enabled", [item.get_meta("bp_id", 0), item.is_checked(0)])


func _on_bp_button_clicked(item: TreeItem, _column: int, _id: int, _mouse_button_index: int) -> void:
	_send("gecs:breakpoint_remove", [item.get_meta("bp_id", 0)])


func _on_clear_log() -> void:
	logs = []
	if log_tree:
		log_tree.clear()
		log_tree.create_item()


func _send(message: String, data: Array) -> bool:
	if send.is_valid():
		return send.call(message, data)
	return false


#endregion Outgoing commands

#region Rendering helpers


func _update_buttons() -> void:
	if pause_btn:
		pause_btn.disabled = paused
	if resume_btn:
		resume_btn.disabled = not paused


func _status_text(s: Dictionary) -> String:
	var bps: Array = s.get("breakpoints", [])
	if not bool(s.get("paused", false)):
		return "Live" + (" (%d breakpoints)" % bps.size() if not bps.is_empty() else "")
	var text := ""
	var cursor: Dictionary = s.get("cursor", {})
	if bool(cursor.get("has_group", false)):
		text = "Paused in group '%s'" % cursor.get("group", "")
		if bool(cursor.get("in_system", false)):
			text += " > %s [unit %d/%d] %s" % [
				cursor.get("system_name", ""),
				int(cursor.get("unit_index", 0)) + 1,
				int(cursor.get("unit_count", 0)),
				cursor.get("unit_label", ""),
			]
		elif str(cursor.get("system_name", "")) != "":
			text += " > next: %s" % cursor.get("system_name", "")
		elif str(cursor.get("next_label", "")) != "":
			text += " > next: %s" % cursor.get("next_label", "")
	else:
		text = "Paused (waiting for the game's next process() call)"
	var pending := int(s.get("pending_requests", 0))
	if pending > 0:
		text += " | %d step(s) pending" % pending
	if bool(s.get("frame_step_active", false)):
		text += " | frame step in progress"
	return text


func _rebuild_breakpoints(bps: Array) -> void:
	if not breakpoints_tree:
		return
	breakpoints_tree.clear()
	var root := breakpoints_tree.create_item()
	var remove_icon: Texture2D = null
	if has_theme_icon("Remove", "EditorIcons"):
		remove_icon = get_theme_icon("Remove", "EditorIcons")
	for bp in bps:
		var row := breakpoints_tree.create_item(root)
		row.set_meta("bp_id", int(bp.get("id", 0)))
		row.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		row.set_checked(0, bool(bp.get("enabled", true)))
		row.set_editable(0, true)
		row.set_text(1, str(bp.get("label", "")))
		row.set_tooltip_text(1, "%s (id %d)" % [bp.get("kind_name", ""), int(bp.get("id", 0))])
		row.set_text(2, str(bp.get("hits", 0)))
		if remove_icon != null:
			row.add_button(2, remove_icon, 0, false, "Remove breakpoint")
	_set_breakpoints_title(bps.size())


func _set_breakpoints_title(count: int) -> void:
	if tabs and tabs.get_tab_count() > 1:
		tabs.set_tab_title(1, "Breakpoints (%d)" % count if count > 0 else "Breakpoints")


## Column texts (Step/op, Kind/target, Ops/detail, ms/cause) for one op record.
func _format_op(op: Array) -> Array:
	if op.size() < 9:
		return [str(op), "", "", ""]
	var code: int = int(op[0])
	var op_name: String = GECSStepper.OP_NAMES[code] if code >= 0 and code < GECSStepper.OP_NAMES.size() else str(code)
	var entity := ("%s#%d" % [op[2], op[1]]) if int(op[1]) != 0 else "-"
	var cause := str(op[7])
	if str(op[8]) != "":
		cause += (" @ " if cause != "" else "@ ") + str(op[8])
	match code:
		GECSStepper.Op.PROP_SET, GECSStepper.Op.SWEEP_SET:
			return [op_name + " " + entity, "%s.%s" % [op[3], op[4]], "%s -> %s" % [_v(op[5]), _v(op[6])], cause]
		GECSStepper.Op.COMP_ADD, GECSStepper.Op.COMP_REMOVE:
			return [op_name + " " + entity, str(op[3]), "", cause]
		GECSStepper.Op.REL_ADD, GECSStepper.Op.REL_REMOVE:
			return [op_name + " " + entity, str(op[3]), "-> " + str(op[4]), cause]
		GECSStepper.Op.ENTITY_ADD, GECSStepper.Op.ENTITY_REMOVE:
			var comps: Array = op[4] if op[4] is Array else []
			return [op_name + " " + entity, str(op[3]), ", ".join(comps), cause]
		GECSStepper.Op.ENTITY_ENABLED:
			return [op_name + " " + entity, "enabled = " + str(op[3]), "", cause]
		GECSStepper.Op.EVENT:
			return [op_name + " " + entity, str(op[3]), _v(op[4]), cause]
	return [op_name + " " + entity, str(op[3]), str(op[4]), cause]


static func _v(value) -> String:
	if value is String:
		return "\"%s\"" % value
	return str(value)


#endregion Rendering helpers
