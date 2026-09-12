@tool
## Shared debugger transport, step options, pause reason and breakpoint controls.
##
## Talks to the game only through [member send] (injected by the tab, wraps
## [method GECSEditorDebuggerTab.send_to_game]) and reports incoming state and
## logs through signals to the surrounding workspace.
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
var step_kind: OptionButton
var step_btn: Button
var transport: HBoxContainer
var options_popup: PopupPanel
var follow_check: CheckBox
var log_hint: Label
var bp_box: VBoxContainer
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
var break_notice: VBoxContainer
var break_reason: Label
var disable_break_btn: Button
var manage_breakpoints_btn: Button
var breakpoints_popup: PopupPanel
var remove_breakpoint_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if pause_btn != null:
		return
	transport = HBoxContainer.new()
	add_child(transport)
	pause_btn = _button(transport, "Pause", "Pause ECS processing. The scene keeps running; only systems stop.", _on_pause)
	resume_btn = _button(transport, "Resume", "Resume live processing (a partially stepped system is finished first).", _on_resume)
	transport.add_child(VSeparator.new())
	var step_label := Label.new()
	step_label.text = "Step by"
	transport.add_child(step_label)
	step_kind = OptionButton.new()
	for kind in KIND_LABELS.size():
		step_kind.add_item(KIND_LABELS[kind], kind)
		step_kind.get_popup().set_item_tooltip(kind, KIND_TOOLTIPS[kind])
	step_kind.select(GECSStepper.Kind.SYSTEM)
	step_kind.item_selected.connect(func(_index: int): _update_step_action())
	transport.add_child(step_kind)
	step_btn = _button(transport, "Step", "Run the selected step. Pauses ECS first if it is live.", func(): _on_step(step_kind.get_selected_id()))
	var options_btn := _button(transport, "Step options", "Step count, entity step set and property sweep.", func():
		options_popup.position = Vector2i(transport.get_screen_position() + Vector2(0, transport.size.y))
		use_selected_btn.disabled = not selected_entities_provider.is_valid() or selected_entities_provider.call().is_empty()
		options_popup.popup()
	)
	options_btn.name = "StepOptions"
	manage_breakpoints_btn = _button(transport, "Breakpoints", "View, disable or remove breakpoints.", _show_breakpoints)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transport.add_child(spacer)
	options_popup = PopupPanel.new()
	add_child(options_popup)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	options_popup.add_child(margin)
	var options := VBoxContainer.new()
	margin.add_child(options)
	var count_row := HBoxContainer.new()
	options.add_child(count_row)
	var count_label := Label.new()
	count_label.text = "Steps per click"
	count_row.add_child(count_label)
	count_spin = SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 1000
	count_spin.value = 1
	count_spin.custom_minimum_size = Vector2(64, 0)
	count_spin.tooltip_text = "Steps per click."
	count_spin.value_changed.connect(func(_value: float): _update_step_action())
	count_row.add_child(count_spin)

	var set_row := HBoxContainer.new()
	options.add_child(set_row)
	step_set_label = Label.new()
	step_set_label.text = "Step set: 0"
	step_set_label.tooltip_text = "Entities that run as their own process() call under Entity stepping."
	set_row.add_child(step_set_label)
	use_selected_btn = _button(set_row, "Use selected entities", "Step through the entities selected in the entity tree.", _on_use_selected)
	clear_set_btn = _button(set_row, "Clear set", "Empty the step set (Entity stepping then behaves like Archetype).", _on_clear_set)
	sweep_check = CheckBox.new()
	sweep_check.text = "Detect unreported property changes"
	sweep_check.button_pressed = true
	sweep_check.tooltip_text = "After every step, diff every component property to catch writes made without an emitting setter (sweep_set ops)."
	sweep_check.toggled.connect(_on_sweep_toggled)
	options.add_child(sweep_check)

	status_label = Label.new()
	status_label.text = "Live"
	status_label.clip_text = true
	status_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(status_label)
	break_notice = VBoxContainer.new()
	add_child(break_notice)
	break_reason = Label.new()
	break_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	break_reason.add_theme_color_override("font_color", COLOR_BREAK)
	break_notice.add_child(break_reason)
	disable_break_btn = _button(break_notice, "Disable this breakpoint", "Disable the breakpoint that caused this pause, then use Resume to continue.", _disable_current_breakpoint)
	disable_break_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	break_notice.hide()

	tabs = TabContainer.new()
	tabs.use_hidden_tabs_for_min_size = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	var log_box := VBoxContainer.new()
	log_box.name = "Step log"
	tabs.add_child(log_box)
	var log_header := HBoxContainer.new()
	log_box.add_child(log_header)
	log_hint = Label.new()
	log_hint.text = "No steps yet. Choose a step size above, then press Step."
	log_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_hint.clip_text = true
	log_header.add_child(log_hint)
	follow_check = CheckBox.new()
	follow_check.text = "Follow latest"
	follow_check.button_pressed = true
	follow_check.tooltip_text = "Scroll to new entries. Turn off to inspect earlier steps."
	log_header.add_child(follow_check)
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

	bp_box = VBoxContainer.new()
	bp_box.name = "Breakpoints"
	tabs.add_child(bp_box)
	var bp_header := HBoxContainer.new()
	bp_box.add_child(bp_header)
	var bp_hint := Label.new()
	bp_hint.text = "Uncheck On to disable."
	bp_hint.tooltip_text = "Disable a breakpoint without deleting it. Press Resume to continue ECS after a pause."
	bp_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_hint.clip_text = true
	bp_header.add_child(bp_hint)
	remove_breakpoint_btn = _button(bp_header, "Remove selected", "Remove the selected breakpoint.", func():
		var row := breakpoints_tree.get_selected()
		if row != null: _send("gecs:breakpoint_remove", [row.get_meta("bp_id", 0)])
	)
	remove_breakpoint_btn.disabled = true
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
	breakpoints_tree.item_selected.connect(func(): remove_breakpoint_btn.disabled = false)
	breakpoints_tree.button_clicked.connect(_on_bp_button_clicked)
	bp_box.add_child(breakpoints_tree)
	_update_buttons()
	_update_step_action()


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
			if not op.is_empty() and op[0] == GECSStepper.Op.SWEEP_SET:
				for c in 5:
					op_row.set_custom_color(c, COLOR_SWEEP)
		log_hint.text = "%d entries · Expand a step to inspect its changes" % logs.size()
		clear_log_btn.disabled = false
		if follow_check.button_pressed:
			log_tree.scroll_to_item(row)
	log_appended.emit(log)


func clear() -> void:
	state = {}
	paused = false
	_on_clear_log()
	if breakpoints_tree:
		breakpoints_tree.clear()
		breakpoints_tree.create_item()
		remove_breakpoint_btn.disabled = true
	if step_set_label:
		step_set_label.text = "Step set: 0"
	if status_label:
		status_label.text = "Live"
		status_label.tooltip_text = ""
	if sweep_check:
		sweep_check.set_pressed_no_signal(true)
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


## Explorer hides the log tabs; keep breakpoint management in its own popup.
func use_breakpoint_popup() -> void:
	if breakpoints_popup != null: return
	breakpoints_popup = PopupPanel.new()
	add_child(breakpoints_popup)
	bp_box.reparent(breakpoints_popup)
	bp_box.custom_minimum_size = Vector2(600, 280)
	bp_box.show()


func _show_breakpoints() -> void:
	if breakpoints_popup != null:
		breakpoints_popup.popup_centered()
	else:
		tabs.current_tab = tabs.get_tab_idx_from_control(bp_box)


func _disable_current_breakpoint() -> void:
	var id := int(state.get("break_info", {}).get("breakpoint_id", 0))
	if paused and id > 0: _send("gecs:breakpoint_set_enabled", [id, false])


func _update_break_notice() -> void:
	if break_notice == null: return
	var info: Dictionary = state.get("break_info", {})
	break_notice.visible = paused and not info.is_empty()
	if not break_notice.visible: return
	var id := int(info.get("breakpoint_id", 0))
	var armed := false
	var exists := false
	for bp in state.get("breakpoints", []):
		if int(bp.get("id", 0)) == id:
			exists = true
			armed = bp.get("enabled", true)
	break_reason.text = "Paused: breakpoint #%d — %s" % [id, info.get("label", "Breakpoint hit")]
	if not str(info.get("system", "")).is_empty(): break_reason.text += "\nSystem: " + str(info.system)
	break_reason.text += "\nResume keeps this breakpoint armed and can pause here again. Disable it to stop these breaks." if armed else "\nThis breakpoint is %s. Press Resume to continue ECS." % ("disabled" if exists else "removed")
	disable_break_btn.visible = armed


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
	if log_hint:
		log_hint.text = "No steps yet. Choose a step size above, then press Step."
	if clear_log_btn:
		clear_log_btn.disabled = true


func _send(message: String, data: Array) -> bool:
	if send.is_valid():
		return send.call(message, data)
	return false


#endregion Outgoing commands

#region Rendering helpers


func _update_buttons() -> void:
	_update_break_notice()
	if pause_btn:
		pause_btn.disabled = paused
		pause_btn.visible = not paused
	if resume_btn:
		resume_btn.disabled = not paused
		resume_btn.visible = paused
	if clear_set_btn:
		clear_set_btn.disabled = state.get("step_entities", []).is_empty()
	if clear_log_btn:
		clear_log_btn.disabled = logs.is_empty()
	if clear_breakpoints_btn:
		clear_breakpoints_btn.disabled = state.get("breakpoints", []).is_empty()
	_update_step_action()


func _update_step_action() -> void:
	if not step_btn or not count_spin:
		return
	var count := int(count_spin.value)
	step_btn.text = "Step" if count == 1 else "Step ×%d" % count
	step_btn.tooltip_text = KIND_TOOLTIPS[step_kind.get_selected_id()] + " Pauses ECS first if live."
	step_kind.tooltip_text = step_btn.tooltip_text
	if step_kind.get_selected_id() == GECSStepper.Kind.ENTITY:
		step_kind.tooltip_text += " Step set: %d entities." % state.get("step_entities", []).size()
		if state.get("step_entities", []).is_empty():
			step_kind.tooltip_text += " Empty set: behaves like Archetype. Select entities and use Step options to set them."


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
	var selected_id := int(breakpoints_tree.get_selected().get_meta("bp_id", 0)) if breakpoints_tree.get_selected() != null else 0
	remove_breakpoint_btn.disabled = true
	breakpoints_tree.clear()
	var root := breakpoints_tree.create_item()
	var remove_icon: Texture2D = null
	if has_theme_icon("Remove", "EditorIcons"):
		remove_icon = get_theme_icon("Remove", "EditorIcons")
	for bp in bps:
		var row := breakpoints_tree.create_item(root)
		row.set_meta("bp_id", int(bp.get("id", 0)))
		if int(bp.get("id", 0)) == selected_id: row.select(0)
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
	if manage_breakpoints_btn:
		manage_breakpoints_btn.text = "Breakpoints (%d)" % count if count > 0 else "Breakpoints"
	if tabs and bp_box and bp_box.get_parent() == tabs:
		tabs.set_tab_title(tabs.get_tab_idx_from_control(bp_box), "Breakpoints (%d)" % count if count > 0 else "Breakpoints")


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
