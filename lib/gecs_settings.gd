class_name GecsSettings
extends Node

const SETTINGS_LOG_LEVEL = "gecs/settings/log_level"
const SETTINGS_DEBUG_MODE = "gecs/settings/debug_mode"
const SETTINGS_SAFE_ITERATION_DEFAULT = "gecs/settings/safe_iteration_default"

const project_settings = {
	"log_level":
	{
		"path": SETTINGS_LOG_LEVEL,
		"default_value": GECSLogger.LogLevel.ERROR,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "TRACE,DEBUG,INFO,WARNING,ERROR",
		"doc": "What log level GECS should log at.",
	},
	"debug_mode":
	{
		"path": SETTINGS_DEBUG_MODE,
		"default_value": false,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"doc":
		"Enable debug mode for GECS operations. Enables editor debugger integration but impacts performance significantly.",
	},
	"safe_iteration_default":
	{
		"path": SETTINGS_SAFE_ITERATION_DEFAULT,
		"default_value": false,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"doc":
		"Default value of System.safe_iteration for all systems. When true, systems copy entity arrays before iteration (v8 behavior) so direct structural mutation mid-loop is safe. When false (default), systems iterate archetype arrays zero-copy and structural changes during iteration must go through the CommandBuffer (cmd).",
	},
}

## Cached project-wide safe_iteration default — read once, reused by every System _init.
static var _safe_iteration_default_cache: int = -1  # -1 unread, 0 false, 1 true


static func get_safe_iteration_default() -> bool:
	if _safe_iteration_default_cache == -1:
		var value: bool = ProjectSettings.get_setting(SETTINGS_SAFE_ITERATION_DEFAULT, false)
		_safe_iteration_default_cache = 1 if value else 0
	return _safe_iteration_default_cache == 1
