class_name GecsSettings
extends Node

const project_settings = {
	"log_level":
	{
		"path": "gecs/log_level",
		"default_value": GECSLogger.LogLevel.DEBUG,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "TRACE,DEBUG,INFO,WARNING,ERROR",
		"doc": "What log level the ECS system should log at.",
	},
	"debug_mode":
	{
		"path": "gecs/debug_mode",
		"default_value": false,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"doc": "Enable debug mode for ECS operations. Enables editor debugger integration but impacts performance.",
	}
}
