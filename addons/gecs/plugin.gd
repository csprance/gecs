@tool
extends EditorPlugin

var gecs_editor_debugger = preload("res://addons/gecs/debug/gecs_editor_debugger.gd").new()


func _enter_tree():
	add_autoload_singleton("ECS", "res://addons/gecs/ecs.gd")
	add_debugger_plugin(gecs_editor_debugger)
	add_gecs_project_settings()


func _exit_tree():
	remove_autoload_singleton("ECS")
	remove_debugger_plugin(gecs_editor_debugger)
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
	documentation: String = ""
):
	if !ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)

	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info(
		{"name": setting_name, "type": value_type, "hint": type_hint, "hint_string": hint_string}
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
			setting["doc"]
		)


## Removes GECS related ProjectSettings from Godot.
func remove_gecs_project_setings():
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	for setting in GecsSettings.project_settings.values():
		ProjectSettings.set_setting(setting["path"], null)

	var error: int = ProjectSettings.save()
	if error != OK:
		push_error("GECS - Encountered error %d while saving project settings." % error)
