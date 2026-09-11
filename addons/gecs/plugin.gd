@tool
extends EditorPlugin

var gecs_editor_debugger = preload("res://addons/gecs/debug/gecs_editor_debugger.gd").new()


var explorer_screen: Control


func _has_main_screen() -> bool:
	return false


func _get_plugin_name() -> String:
	return "GECS"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Search", "EditorIcons")


func _make_visible(visible: bool) -> void:
	if visible and explorer_screen != null: explorer_screen.open_window()


func _enter_tree():
	add_autoload_singleton("ECS", "res://addons/gecs/ecs/ecs.gd")
	explorer_screen = preload("res://addons/gecs/debug/explorer/gecs_explorer_host.gd").new()
	explorer_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	explorer_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The Explorer is a companion to the game, not an editor main screen. Keep a
	# hidden owner under the editor while its content lives in a native window.
	get_editor_interface().get_base_control().add_child(explorer_screen)
	var welcome := Label.new()
	welcome.name = "Welcome"
	welcome.text = "GECS Explorer\n\nRun a scene with an ECS World to begin.\nFind entities, inspect component data, pin watches, edit, and step."
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explorer_screen.sessions.add_child(welcome)
	explorer_screen.hide()
	gecs_editor_debugger.main_screen = explorer_screen.sessions
	gecs_editor_debugger.open_explorer = explorer_screen.open_window
	# Pass editor interface to debugger so it can select nodes
	gecs_editor_debugger.editor_interface = get_editor_interface()
	add_debugger_plugin(gecs_editor_debugger)
	add_gecs_project_settings()


func _exit_tree():
	remove_autoload_singleton("ECS")
	remove_debugger_plugin(gecs_editor_debugger)
	if explorer_screen != null: explorer_screen.queue_free()
	# remove_gecs_project_setings()


func _on_settings_changed():
	pass


## Adds a new project setting to Godot.
## TODO: Figure out how to also add the documentation to the ProjectSetting so that it shows up
## in the Godot Editor tooltip when the setting is hovered over.
func add_project_setting(
	setting_name: String,
	default_value: Variant,
	value_type: int,
	type_hint: int = PROPERTY_HINT_NONE,
	hint_string: String = "",
	documentation: String = "",
):
	if !ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)

	ProjectSettings.set_initial_value(setting_name, default_value)
	(
		ProjectSettings
		.add_property_info(
			{
				"name": setting_name,
				"type": value_type,
				"hint": type_hint,
				"hint_string": hint_string
			},
		)
	)
	ProjectSettings.set_as_basic(setting_name, true)

	var error: int = ProjectSettings.save()
	if error:
		push_error("GECS - Encountered error %d while saving project settings." % error)


## Adds new GECS related ProjectSettings to Godot.
func add_gecs_project_settings():
	ProjectSettings.settings_changed.connect(_on_settings_changed)
	for setting in GecsSettings.project_settings.values():
		add_project_setting(
			setting["path"],
			setting["default_value"],
			setting["type"],
			setting["hint"],
			setting["hint_string"],
			setting["doc"],
		)
	add_gecs_network_project_settings()


## Adds GECS Network related ProjectSettings to Godot.
func add_gecs_network_project_settings():
	add_project_setting("gecs/network/sync/high_hz", 20, TYPE_INT)
	add_project_setting("gecs/network/sync/medium_hz", 10, TYPE_INT)
	add_project_setting("gecs/network/sync/low_hz", 2, TYPE_INT)
	add_project_setting("gecs/network/sync/reconciliation_interval", 30.0, TYPE_FLOAT)


## Removes GECS related ProjectSettings from Godot.
func remove_gecs_project_setings():
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	for setting in GecsSettings.project_settings.values():
		ProjectSettings.set_setting(setting["path"], null)

	var error: int = ProjectSettings.save()
	if error != OK:
		push_error("GECS - Encountered error %d while saving project settings." % error)
