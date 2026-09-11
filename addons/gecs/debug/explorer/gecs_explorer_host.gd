@tool
extends VBoxContainer
## Owns the persistent native companion window used by every debug session.
## Closing the window only hides it, so views, subscriptions, and drafts survive.
const UI = preload("res://addons/gecs/debug/explorer/gecs_explorer_ui.gd")

signal opened
signal window_hidden

var sessions := TabContainer.new()
var content := PanelContainer.new()
var window: Window
var _placeholder := VBoxContainer.new()
var _on_top := CheckButton.new()
var _last_size := Vector2i(1200, 800)
var _last_position := Vector2i.ZERO
var _has_position := false


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.theme = UI.make_theme()
	content.add_theme_stylebox_override("panel", UI.style(UI.BACKGROUND, 10, 0))
	add_child(content)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", UI.px(8))
	content.add_child(shell)
	var bar := HBoxContainer.new()
	shell.add_child(bar)
	UI.label(bar, "◈", 20, UI.ACCENT)
	UI.label(bar, "GECS", 18)
	var subtitle := UI.label(bar, "EXPLORER", 12, UI.MUTED)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_on_top.text = "Always on top"
	_on_top.toggled.connect(func(enabled: bool):
		if is_instance_valid(window): window.always_on_top = enabled
	)
	bar.add_child(_on_top)
	sessions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sessions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sessions.use_hidden_tabs_for_min_size = false
	# Keep controls reachable on small displays or at large editor UI scales.
	# At normal sizes the session fills this viewport without scrollbars.
	var viewport := ScrollContainer.new()
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.follow_focus = true
	shell.add_child(viewport)
	viewport.add_child(sessions)
	sessions.child_entered_tree.connect(func(_node: Node): _update_session_tabs.call_deferred())
	sessions.child_exiting_tree.connect(func(_node: Node): _update_session_tabs.call_deferred())
	add_child(_placeholder)
	_placeholder.hide()
	var label := Label.new()
	label.text = "GECS Explorer is a companion window so the game remains visible."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placeholder.add_child(label)
	var focus := Button.new()
	focus.text = "Focus Explorer window"
	focus.pressed.connect(open_window)
	_placeholder.add_child(focus)
	_placeholder.hide()


func open_window() -> void:
	if is_instance_valid(window):
		window.show()
		if window.mode == Window.MODE_MINIMIZED: window.mode = Window.MODE_WINDOWED
		window.grab_focus()
		return
	window = Window.new()
	window.title = "GECS Explorer"
	window.visible = false
	# Native even if the game/editor embeds subwindows. Neither modal nor
	# transient: the game and the editor must continue accepting input.
	window.force_native = true
	window.transient = false
	window.exclusive = false
	window.min_size = Vector2i(UI.px(900), UI.px(640))
	window.size = _last_size
	window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	window.always_on_top = _on_top.button_pressed
	window.theme = content.theme
	add_child(window)
	content.reparent(window, false)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.close_requested.connect(hide_window)
	window.show()
	if _has_position:
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		if screen.encloses(Rect2i(_last_position, Vector2i(80, 40))): window.position = _last_position
	opened.emit()
	window.grab_focus()


func hide_window() -> void:
	if not is_instance_valid(window): return
	_last_size = window.size
	_last_position = window.position
	_has_position = true
	window.hide()
	window_hidden.emit()


func _exit_tree() -> void:
	# Native windows belong to this host and are freed with the plugin.
	if is_instance_valid(window): window.hide()

func _update_session_tabs() -> void:
	var count := 0
	for index in sessions.get_tab_count():
		if not sessions.is_tab_hidden(index): count += 1
	sessions.tabs_visible = count > 1
