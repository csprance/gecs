@tool
extends EditorPlugin

const ADDONS_PATH := "res://addons/"
const PLUGIN_CONFIG_DIR := "plugins/plugin_refresher"
const PLUGIN_CONFIG := "settings.cfg"
const PLUGIN_NAME := "Godot Plugin Refresher"
const SETTINGS := "settings"
const SETTING_RECENT := "recently_used"
const Refresher := preload("plugin_refresher.gd")

var plugin_config := ConfigFile.new()
var refresher: Refresher = null


func _enter_tree() -> void:
	refresher = preload("plugin_refresher.tscn").instantiate() as Refresher
	add_control_to_container(CONTAINER_TOOLBAR, refresher)

	# Watch whether any plugin is changed, added or removed on the filesystem
	var efs := EditorInterface.get_resource_filesystem()
	efs.filesystem_changed.connect(_on_filesystem_changed)

	refresher.request_refresh_plugin.connect(_on_request_refresh_plugin)
	refresher.confirm_refresh_plugin.connect(_on_confirm_refresh_plugin)

	_reload_plugins_list()
	_load_settings()


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_TOOLBAR, refresher)
	refresher.free()


func _reload_plugins_list() -> void:
	var cfg_paths: Array[String] = []
	var plugins := {}
	var display_names_map := {} # full path to display name

	find_cfgs(ADDONS_PATH, cfg_paths)

	for cfg_path in cfg_paths:
		var plugin_cfg := ConfigFile.new()
		var err := plugin_cfg.load(cfg_path)
		if err:
			push_error("ERROR LOADING PLUGIN FILE: %s" % err)
		else:
			var plugin_name := plugin_cfg.get_value("plugin", "name")
			if plugin_name != PLUGIN_NAME:
				var addon_dir_name = cfg_path.split("addons/")[-1].split("/plugin.cfg")[0]
				plugins[addon_dir_name] = [plugin_name, cfg_path]

	# This will be an array of the addon/* directory names.
	var plugin_dirs: Array[String] = []
	plugin_dirs.assign(plugins.keys()) # typed array "casting"

	var plugin_names: Array[String] = []
	plugin_names.assign(plugin_dirs.map(func(k): return plugins[k][0]))

	for plugin_dirname in plugin_dirs:
		var plugin_name = plugins[plugin_dirname][0]
		var display_name = plugin_name if plugin_names.count(plugin_name) == 1 else "%s (%s)" % [plugin_name, plugin_dirname]
		display_names_map[plugins[plugin_dirname][1]] = display_name

	refresher.update_items([plugins, display_names_map])


func find_cfgs(dir_path: String, cfgs: Array):
	var dir := DirAccess.open(dir_path)
	var cfg_path := dir_path.path_join("plugin.cfg")

	if dir.file_exists(cfg_path):
		cfgs.append(cfg_path)
		return

	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				find_cfgs(dir_path.path_join(file_name), cfgs)
			file_name = dir.get_next()


func _load_settings() -> void:
	var path := get_settings_path()

	if not FileAccess.file_exists(path):
		# Create new if running for the first time
		var config := ConfigFile.new()
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		config.save(path)
	else:
		plugin_config.load(path)


func _save_settings() -> void:
	plugin_config.save(get_settings_path())


func get_settings_path() -> String:
	var editor_paths := EditorInterface.get_editor_paths()
	var dir := editor_paths.get_project_settings_dir()

	var home := dir.path_join(PLUGIN_CONFIG_DIR)
	var path := home.path_join(PLUGIN_CONFIG)

	return path


func _on_filesystem_changed() -> void:
	if refresher:
		_reload_plugins_list()
		var recent = get_recent_plugin()
		if recent:
			refresher.select_plugin(recent)


func get_recent_plugin() -> String:
	if not plugin_config.has_section_key(SETTINGS, SETTING_RECENT):
		return "" # not saved yet

	var recent = str(plugin_config.get_value(SETTINGS, SETTING_RECENT))
	return recent


func _on_request_refresh_plugin(p_path: String) -> void:
	assert(not p_path.is_empty())

	var disabled := not EditorInterface.is_plugin_enabled(p_path)
	if disabled:
		refresher.show_warning(p_path)
	else:
		refresh_plugin(p_path)


func _on_confirm_refresh_plugin(p_path: String) -> void:
	refresh_plugin(p_path)


func get_plugin_path() -> String:
	return get_script().resource_path.get_base_dir()


func refresh_plugin(p_path: String) -> void:
	print("Refreshing plugin: ", p_path)

	var enabled := EditorInterface.is_plugin_enabled(p_path)
	if enabled: # can only disable an active plugin
		EditorInterface.set_plugin_enabled(p_path, false)

	EditorInterface.set_plugin_enabled(p_path, true)

	plugin_config.set_value(SETTINGS, SETTING_RECENT, p_path)
	_save_settings()
