@tool
extends EditorPlugin
## GECS Network Plugin
##
## Adds network synchronization capabilities to GECS.
## Attach NetworkSync as a child of your World node to enable multiplayer.
##
## Features:
## - NetworkSync: Main synchronization node
## - CN_NetworkIdentity: Entity ownership component
## - CN_NativeSync: Native MultiplayerSynchronizer sync configuration component
## - Marker components: CN_LocalAuthority, CN_RemoteEntity, CN_ServerAuthority

const PLUGIN_NAME = "GECSNetwork"

# Icon paths (optional - gracefully degrades if not present)
const ICON_PATH = "res://addons/gecs_network/icons/"

# Custom type registration data
const CUSTOM_TYPES = {
	"NetworkSync":
	{
		"base": "Node",
		"script": "res://addons/gecs_network/network_sync.gd",
		"icon": "network_sync.svg"
	},
	"TransportProvider":
	{"base": "RefCounted", "script": "res://addons/gecs_network/transport_provider.gd", "icon": ""},
	"ENetTransportProvider":
	{
		"base": "RefCounted",
		"script": "res://addons/gecs_network/transports/enet_transport_provider.gd",
		"icon": ""
	},
	"SteamTransportProvider":
	{
		"base": "RefCounted",
		"script": "res://addons/gecs_network/transports/steam_transport_provider.gd",
		"icon": ""
	}
}


func _enter_tree() -> void:
	# Register custom types
	for type_name in CUSTOM_TYPES.keys():
		var type_data = CUSTOM_TYPES[type_name]
		var script = load(type_data["script"])

		# Skip registration if script failed to load
		if script == null:
			push_error(
				(
					"[%s] Failed to load script for %s: %s"
					% [PLUGIN_NAME, type_name, type_data["script"]]
				)
			)
			continue

		var icon = _load_icon(type_data["icon"])
		add_custom_type(type_name, type_data["base"], script, icon)

	_register_project_settings()

	print("[%s] Plugin enabled - %s registered" % [PLUGIN_NAME, ", ".join(CUSTOM_TYPES.keys())])


func _exit_tree() -> void:
	# Remove custom types
	for type_name in CUSTOM_TYPES.keys():
		remove_custom_type(type_name)

	print("[%s] Plugin disabled" % PLUGIN_NAME)


## Load an icon from the icons folder, returns null if not found.
## Missing icons gracefully fall back to Godot's default icons.
func _load_icon(icon_name: String) -> Texture2D:
	var icon_path = ICON_PATH + icon_name
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	return null


## Register gecs_network ProjectSettings for sync Hz values.
## Called from _enter_tree() so settings appear in Project Settings dialog.
## Safe to call multiple times — set_setting() is idempotent.
func _register_project_settings() -> void:
	_add_setting("gecs_network/sync/high_hz", 20, TYPE_INT)
	_add_setting("gecs_network/sync/medium_hz", 10, TYPE_INT)
	_add_setting("gecs_network/sync/low_hz", 2, TYPE_INT)


func _add_setting(path: String, default_value: Variant, type: int) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({"name": path, "type": type})
