class_name GecsSettings
extends Node

const SETTINGS_LOG_LEVEL = "gecs/settings/log_level"
const SETTINGS_DEBUG_MODE = "gecs/settings/debug_mode"

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
		"doc": "Enable debug mode for GECS operations. Enables editor debugger integration but impacts performance significantly.",
	}
}
