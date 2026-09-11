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
	if message == "gecs:explorer_response":
		model.accept(data[0])
		return true
	if message == "gecs:explorer_event":
		model.event(data[0])
		return true
	if message == Msg.GRAPH_STATE and model.graph_ids.has(int(data[0])):
		model.updated.emit("graph", {"id": data[0], "step": data[1], "graph": data[2]})
		return true
	var captured := _capture_legacy(message, data, tab)
	if message in [Msg.WORLD_INIT, Msg.SET_WORLD]:
		if not data.is_empty(): model.request("hello")
		else: model.invalidate_world()
	elif message == Msg.EXIT_WORLD:
		model.invalidate_world()
	elif message == Msg.STEP_STATE:
		var preferred: int = model.step_state.get("preferred_kind", 2)
		model.step_state = data[0].duplicate(true)
		model.step_state["preferred_kind"] = preferred
		model.updated.emit("step", model.step_state)
	elif message == Msg.STEP_LOG:
		model.updated.emit("log", data[0])
	elif message in [Msg.SYSTEM_ADDED, Msg.SYSTEM_REMOVED, Msg.SYSTEM_LAST_RUN_DATA]:
		model.updated.emit("systems", tab.ecs_data.get("systems", {}))
	return captured


func _capture_legacy(message: String, data: Array, debugger_tab: GECSEditorDebuggerTab) -> bool:
	if message == Msg.WORLD_INIT:
		# data: [World.get_path()]
		var world = data[0]
		var world_path = data[1]
		debugger_tab.world_init(data[0], data[1])
		return true
	elif message == Msg.SYSTEM_METRIC:
		# data: [system, system_name, elapsed_time]
		var system = data[0]
		var system_name = data[1]
		var elapsed_time = data[2]
		debugger_tab.system_metric(system, system_name, elapsed_time)
		return true
	elif message == Msg.SYSTEM_LAST_RUN_DATA:
		# data: [system_id, system_name, last_run_data]
		var system_id = data[0]
		var system_name = data[1]
		var last_run_data = data[2]
		debugger_tab.system_last_run_data(system_id, system_name, last_run_data)
		return true
	elif message == Msg.SET_WORLD:
		if data.size() == 0:
			return true
		var world = data[0]
		var world_path = data[1]
		debugger_tab.set_world(world, world_path)
		return true
	elif message == Msg.PROCESS_WORLD:
		# data: [float, String]
		var delta = data[0]
		var group_name = data[1]
		debugger_tab.process_world(delta, group_name)
		return true
	elif message == Msg.EXIT_WORLD:
		debugger_tab.exit_world()
		return true
	elif message == Msg.ENTITY_ADDED:
		# data: [Entity, NodePath]
		debugger_tab.entity_added(data[0], data[1])
		return true
	elif message == Msg.ENTITY_REMOVED:
		# data: [Entity, NodePath]
		debugger_tab.entity_removed(data[0], data[1])
		return true
	elif message == Msg.ENTITY_DISABLED:
		# data: [Entity, NodePath]
		debugger_tab.entity_disabled(data[0], data[1])
		return true
	elif message == Msg.ENTITY_ENABLED:
		# data: [Entity, NodePath]
		debugger_tab.entity_enabled(data[0], data[1])
		return true
	elif message == Msg.SYSTEM_ADDED:
		# data: [System, group, process_empty, active, paused, NodePath]
		debugger_tab.system_added(data[0], data[1], data[2], data[3], data[4], data[5])
		return true
	elif message == Msg.SYSTEM_REMOVED:
		# data: [System, NodePath]
		debugger_tab.system_removed(data[0], data[1])
		return true
	elif message == Msg.ENTITY_COMPONENT_ADDED:
		# data: [ent.get_instance_id(), comp.get_instance_id(), ClassUtils.get_type_name(comp), comp.serialize()]
		debugger_tab.entity_component_added(data[0], data[1], data[2], data[3])
		return true
	elif message == Msg.ENTITY_COMPONENT_REMOVED:
		# data: [Entity, Variant]
		debugger_tab.entity_component_removed(data[0], data[1])
		return true
	elif message == Msg.ENTITY_RELATIONSHIP_ADDED:
		# data: [ent_id, rel_id, rel_data]
		debugger_tab.entity_relationship_added(data[0], data[1], data[2])
		return true
	elif message == Msg.ENTITY_RELATIONSHIP_REMOVED:
		# data: [Entity, Relationship]
		debugger_tab.entity_relationship_removed(data[0], data[1])
		return true
	elif message == Msg.COMPONENT_PROPERTY_CHANGED:
		# data: [Entity, Component, property_name, old_value, new_value]
		debugger_tab.entity_component_property_changed(data[0], data[1], data[2], data[3], data[4])
		return true
	elif message == Msg.ENTITY_COMPONENTS_SYNCED:
		# data: [entity_id, comp_ids]
		debugger_tab.entity_components_synced(data[0], data[1])
		return true
	elif message == Msg.ENTITY_QUERY_RESULT:
		# data: [entity_ids, error]
		debugger_tab.entity_query_result(data[0], data[1])
		return true
	elif message == Msg.READY:
		# The game announced it has GECS: reply with a subscription.
		debugger_tab.on_game_ready()
		return true
	elif message == Msg.STEP_STATE:
		# data: [state] (GECSStepper.state())
		debugger_tab.step_state(data[0])
		return true
	elif message == Msg.STEP_LOG:
		# data: [log] (one step / break / external entry with its ops)
		debugger_tab.step_log(data[0])
		return true
	elif message == Msg.GRAPH_STATE:
		# data: [graph_id, step_id, graph] (GECSGraphState.build)
		debugger_tab.graph_state(data[0], data[1], data[2])
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
		# The debugger remains a compact transport/log surface.
		tab.step_panel.tabs.set_tab_hidden(0, true)
		tab.step_panel.tabs.set_tab_hidden(1, true)
		tab.step_panel.tabs.current_tab = 2
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
	model.request("hello")
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
		tab._close_all_graph_windows(false)
	var model: GECSExplorerModel = models.get(session_id)
	if model != null: model.disconnect_session()
