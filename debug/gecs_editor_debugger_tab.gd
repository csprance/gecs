@tool
class_name GECSEditorDebuggerTab
extends Control
## Compact session surface. Explorer owns entity/system inspection.
@onready var step_panel: GECSEditorStepPanel = %StepPanel
@onready var debug_mode_overlay: Panel = %DebugModeOverlay
var active := false
var model: GECSExplorerModel
var _debugger_session: EditorDebuggerSession

func _ready() -> void:
	step_panel.send = send_to_game
	debug_mode_overlay.visible = not ProjectSettings.get_setting(GecsSettings.SETTINGS_DEBUG_MODE, false)
	move_child(debug_mode_overlay, get_child_count() - 1)

func set_debugger_session(session: EditorDebuggerSession) -> void:
	_debugger_session = session

func set_editor_interface(_interface) -> void:
	pass

func send_to_game(message: String, data: Array = []) -> bool:
	if _debugger_session == null or not _debugger_session.is_active(): return false
	_debugger_session.send_message(message, data)
	if model != null and message not in ["gecs:explorer_request", "gecs:subscribe", "gecs:unsubscribe"]:
		model.refresh()
	return true

func on_game_ready() -> void:
	if model == null or not model.connected: return
	send_to_game("gecs:subscribe", [])
	if not model.has_pending("hello"): model.request("hello")

func clear_all_data() -> void:
	if step_panel != null: step_panel.clear()

func step_state(state: Dictionary) -> void:
	step_panel.apply_state(state)

func step_log(log: Dictionary) -> void:
	step_panel.append_log(log)
