@tool
extends EditorPlugin
## GECS Network Plugin
##
## Adds network synchronization capabilities to GECS.
## Attach NetworkSync as a child of your World node to enable multiplayer.
##
## Features:
## - NetworkSync: Main synchronization node
## - SyncConfig: Priority and filtering configuration
## - C_NetworkIdentity: Entity ownership component
## - C_SyncEntity: Native sync configuration component
## - Marker components: C_LocalAuthority, C_RemoteEntity, C_ServerOwned

const PLUGIN_NAME = "GECSNetwork"

# Icon paths (optional - gracefully degrades if not present)
const ICON_PATH = "res://addons/gecs_network/icons/"

# Custom type registration data
const CUSTOM_TYPES = {
	"NetworkSync": {
		"base": "Node",
		"script": "res://addons/gecs_network/network_sync.gd",
		"icon": "network_sync.svg"
	},
	"SyncConfig": {
		"base": "Resource",
		"script": "res://addons/gecs_network/sync_config.gd",
		"icon": "sync_config.svg"
	}
}


func _enter_tree() -> void:
	# Register custom types
	for type_name in CUSTOM_TYPES.keys():
		var type_data = CUSTOM_TYPES[type_name]
		var script = _load_script(type_data["script"])
		var icon = _load_icon(type_data["icon"])

		if script:
			add_custom_type(type_name, type_data["base"], script, icon)
		else:
			push_error("[%s] Failed to load script: %s" % [PLUGIN_NAME, type_data["script"]])

	print("[%s] Plugin enabled - NetworkSync, SyncConfig registered" % PLUGIN_NAME)


func _exit_tree() -> void:
	# Remove custom types
	for type_name in CUSTOM_TYPES.keys():
		remove_custom_type(type_name)

	print("[%s] Plugin disabled" % PLUGIN_NAME)


## Load a script, returns null if not found.
## Missing scripts will cause a registration error.
func _load_script(script_path: String) -> Script:
	if ResourceLoader.exists(script_path):
		return load(script_path)
	return null


## Load an icon from the icons folder, returns null if not found.
## Missing icons gracefully fall back to Godot's default icons.
func _load_icon(icon_name: String) -> Texture2D:
	var icon_path = ICON_PATH + icon_name
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	return null
