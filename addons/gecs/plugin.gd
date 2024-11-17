@tool
extends EditorPlugin

var setting_name = 'gecs/entity_base_type'

func _enter_tree():
	add_autoload_singleton("ECS", "res://addons/gecs/ecs.gd")
	# Add the editor setting
	ProjectSettings.set_setting(setting_name, 'Node2D')
	ProjectSettings.set_initial_value(setting_name, 'Node2D')
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Node2D,Node3D",
	})
	ProjectSettings.set_as_basic(setting_name, true)
	# Connect to setting changed signal
	ProjectSettings.settings_changed.connect(_on_settings_changed)
	ProjectSettings.save()
	# Apply the current setting
	_apply_entity_base_type(ProjectSettings.get(setting_name))

func _exit_tree():
	remove_autoload_singleton("ECS")
	# Disconnect the signal
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	ProjectSettings.set_setting(setting_name, null)
	ProjectSettings.save()

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
