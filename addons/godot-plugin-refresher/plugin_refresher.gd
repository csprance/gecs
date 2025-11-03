@tool
extends HBoxContainer

signal request_refresh_plugin(p_name: String)
signal confirm_refresh_plugin(p_name: String)

@onready var options: OptionButton = $OptionButton


func _ready() -> void:
	if get_tree().edited_scene_root == self:
		return # This is the scene opened in the editor!
	$RefreshButton.icon = EditorInterface.get_editor_theme().get_icon("Reload", "EditorIcons")


func update_items(p_plugins_info: Array) -> void:
	if not options:
		return
	options.clear()

	var plugins := p_plugins_info[0] as Dictionary
	var display_names_map := p_plugins_info[1] as Dictionary

	var plugin_dirs: Array[String] = []
	plugin_dirs.assign(plugins.keys())
	for idx in plugin_dirs.size():
		var plugin_dirname := plugin_dirs[idx]
		var plugin_data = plugins[plugin_dirname] # Array[String] used as a Tuple<String, String>.
		var plugin_name := plugin_data[0] as String
		var plugin_path := plugin_data[1] as String
		var display_name := display_names_map[plugin_path] as String

		options.add_item(display_name, idx)
		options.set_item_metadata(idx, plugin_path)


# Note: For whatever reason, statically typing `p_name` inexplicably causes
# an error about converting from Nil to String, even if the value is converted.
func select_plugin(p_name) -> void:
	if not options or not p_name:
		return

	for idx in options.get_item_count():
		var plugin := str(options.get_item_metadata(idx))
		if plugin == str(p_name):
			options.selected = options.get_item_id(idx)
			break


func _on_RefreshButton_pressed() -> void:
	if options.selected == -1:
		return # nothing selected

	var plugin := str(options.get_item_metadata(options.selected))
	if not plugin:
		return
	emit_signal("request_refresh_plugin", plugin)


func show_warning(p_name: String) -> void:
	$ConfirmationDialog.dialog_text = (
		"""
		Plugin `%s` is currently disabled.\n
		Do you want to enable it now?
	"""
		% [p_name]
	)
	$ConfirmationDialog.popup_centered()


func _on_ConfirmationDialog_confirmed() -> void:
	var plugin := options.get_item_metadata(options.selected) as String
	emit_signal("confirm_refresh_plugin", plugin)
