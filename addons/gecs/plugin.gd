@tool
extends EditorPlugin

var setting_name = 'gecs/entity_base_type'

func _enter_tree():
	add_autoload_singleton("ECS", "res://addons/gecs/ecs.gd")
	add_gecs_project_settings()

func _exit_tree():
	remove_autoload_singleton("ECS")
	remove_gecs_project_setings()

func _on_settings_changed():
	var base_type = ProjectSettings.get(setting_name)
	_apply_entity_base_type(base_type)

func _apply_entity_base_type(base_type):
	var entity_script_path = "res://addons/gecs/entity.gd"
	var file = FileAccess.open(entity_script_path, FileAccess.READ_WRITE)
	if file:
		var lines = file.get_as_text().split("\n")
		for i in lines.size():
			if lines[i].begins_with("extends "):
				lines[i] = "extends " + base_type
				break
		file.seek(0)
		file.store_string('\n'.join(lines))
		file.close()

## Adds a new project setting to Godot.
## TODO: Figure out how to also add the documentation to the ProjectSetting so that it shows up 
## in the Godot Editor tooltip when the setting is hovered over.
func add_project_setting(setting_name: String, default_value : Variant, value_type: int, type_hint: int = PROPERTY_HINT_NONE, hint_string: String = "", documentation : String = ""):
	if !ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
		
	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({	"name": setting_name, "type": value_type, "hint": type_hint, "hint_string": hint_string})
	ProjectSettings.set_as_basic(setting_name, true)

	var error: int = ProjectSettings.save()
	if error: 
		push_error("GECS - Encountered error %d while saving project settings." % error)

## Adds new Loggie related ProjectSettings to Godot.
func add_gecs_project_settings():
	ProjectSettings.settings_changed.connect(_on_settings_changed)
	for setting in GecsSettings.project_settings.values():
		add_project_setting(setting["path"], setting["default_value"], setting["type"], setting["hint"], setting["hint_string"], setting["doc"])

## Removes Loggie related ProjectSettings from Godot.
func remove_gecs_project_setings():
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	for setting in GecsSettings.project_settings.values():
		ProjectSettings.set_setting(setting["path"], null)
	
	var error: int = ProjectSettings.save()
	if error != OK: 
		push_error("GECS - Encountered error %d while saving project settings." % error)