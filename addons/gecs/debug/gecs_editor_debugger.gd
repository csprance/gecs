class_name GECSEditorDebugger
extends EditorDebuggerPlugin

## The Debugger session for the current game
var session: EditorDebuggerSession
## The tab that will be added to the debugger window
var debugger_tab: GECSEditorDebuggerTab
var session_tabs: Dictionary = {}
var models: Dictionary = {}
var workspaces: Dictionary = {}
var main_screen: TabContainer
var open_explorer: Callable


## The debugger messages that will be sent to the editor debugger
var Msg := GECSEditorDebuggerMessages.Msg
## Reference to editor interface for selecting nodes
var editor_interface: EditorInterface = null


func _has_capture(capture):
	# Return true if you wish to handle messages with the prefix "gecs:".
	return capture == "gecs"


func _capture(message: String, data: Array, session_id: int) -> bool:
	var tab: GECSEditorDebuggerTab = session_tabs.get(session_id)
	var model: GECSExplorerModel = models.get(session_id)
	if tab == null or model == null: return false
	if message == "gecs:explorer_response" and not data.is_empty() and data[0] is Dictionary:
		model.accept(data[0])
		return true
	if message == "gecs:explorer_event" and not data.is_empty() and data[0] is Dictionary:
		model.event(data[0])
		return true
	if message == Msg.READY:
		tab.on_game_ready()
		return true
	if message in [Msg.WORLD_INIT, Msg.SET_WORLD, Msg.EXIT_WORLD]:
		model.invalidate_world()
		return true
	return false


func _setup_session(session_id):
	var session := get_session(session_id)
	var tab: GECSEditorDebuggerTab = preload("res://addons/gecs/debug/gecs_editor_debugger_tab.tscn").instantiate()
	tab.name = "GECS"
	tab.set_debugger_session(session)
	tab.set_editor_interface(editor_interface)
	session_tabs[session_id] = tab
	debugger_tab = tab
	var model := GECSExplorerModel.new()
	model.session_id = session_id
	model.sender = tab.send_to_game
	tab.model = model
	model.updated.connect(func(kind: String, data: Dictionary):
		if kind == "step": tab.step_state(data)
		elif kind == "hello": tab.step_state(model.step_state)
		elif kind == "log": tab.step_log(data)
		elif kind == "connection_error": tab.step_panel.status_label.text = data.error
	)
	models[session_id] = model
	session.started.connect(_on_session_started.bind(session_id))
	session.stopped.connect(_on_session_stopped.bind(session_id))
	session.breaked.connect(func(_debuggable: bool):
		model.script_breaked = true
		model.updated.emit("step", model.step_state)
	)
	session.continued.connect(func():
		model.script_breaked = false
		model.updated.emit("step", model.step_state)
	)
	session.add_session_tab(tab)
	if main_screen != null:
		var workspace := GECSExplorerWorkspace.new()
		workspace.name = "Session %d" % (session_id + 1)
		workspace.configure(model)
		main_screen.add_child(workspace)
		workspaces[session_id] = workspace
		main_screen.current_tab = workspace.get_index()
		if main_screen.get_child(0).name == "Welcome": main_screen.set_tab_hidden(0, true)
		tab.step_panel.selected_entities_provider = func():
			var view := workspace.active_view()
			return [view.ref.iid] if view != null else []
		var explorer_button := Button.new()
		explorer_button.text = "Show Explorer"
		explorer_button.tooltip_text = "Show the GECS companion window beside the running game."
		explorer_button.pressed.connect(func():
			if is_instance_valid(main_screen): main_screen.current_tab = workspace.get_index()
			if open_explorer.is_valid(): open_explorer.call()
		)
		tab.step_panel.transport.add_child(explorer_button)


func _on_session_started(session_id := 0):
	var tab: GECSEditorDebuggerTab = session_tabs.get(session_id)
	var model: GECSExplorerModel = models.get(session_id)
	if tab == null: return
	tab.clear_all_data()
	tab.active = true
	model.connected = true
	model.script_breaked = false
	tab.on_game_ready()
	# Godot reuses debugger sessions across runs. Open on every start, not
	# during setup (which also runs when the editor first loads the plugin).
	var workspace: GECSExplorerWorkspace = workspaces.get(session_id)
	if is_instance_valid(main_screen) and is_instance_valid(workspace):
		main_screen.current_tab = workspace.get_index()
	if open_explorer.is_valid(): open_explorer.call_deferred()


func _on_session_stopped(session_id := 0):
	var tab: GECSEditorDebuggerTab = session_tabs.get(session_id)
	if tab != null:
		tab.active = false
	var model: GECSExplorerModel = models.get(session_id)
	if model != null: model.disconnect_session()
