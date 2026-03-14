## Simplified Logger for GECS
class_name GECSLogger
extends RefCounted

const disabled := true

enum LogLevel {TRACE, DEBUG, INFO, WARNING, ERROR}

var current_level: LogLevel = ProjectSettings.get_setting(GecsSettings.SETTINGS_LOG_LEVEL, LogLevel.ERROR)
var current_domain: String = ""


func set_level(level: LogLevel):
	current_level = level


func domain(domain_name: String) -> GECSLogger:
	current_domain = domain_name
	return self


func log(level: LogLevel, msg = ""):
	if disabled:
		return
	var level_name: String
	if level >= current_level:
		match level:
			LogLevel.TRACE:
				level_name = "TRACE"
			LogLevel.DEBUG:
				level_name = "DEBUG"
			LogLevel.INFO:
				level_name = "INFO"
			LogLevel.WARNING:
				level_name = "WARNING"
			LogLevel.ERROR:
				level_name = "ERROR"
			_:
				level_name = "UNKNOWN"
		print("%s [%s]: %s" % [current_domain, level_name, msg])


func trace(msg = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	self.log(LogLevel.TRACE, concatenate_msg_and_args(msg, arg1, arg2, arg3, arg4, arg5))


func debug(msg = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	self.log(LogLevel.DEBUG, concatenate_msg_and_args(msg, arg1, arg2, arg3, arg4, arg5))


func info(msg = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	self.log(LogLevel.INFO, concatenate_msg_and_args(msg, arg1, arg2, arg3, arg4, arg5))


func warning(msg = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	self.log(LogLevel.WARNING, concatenate_msg_and_args(msg, arg1, arg2, arg3, arg4, arg5))


func error(msg = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	self.log(LogLevel.ERROR, concatenate_msg_and_args(msg, arg1, arg2, arg3, arg4, arg5))

## Concatenates all given args into one single string, in consecutive order starting with 'msg'.[br]
## Stolen from Loggie
static func concatenate_msg_and_args(
	msg: Variant,
	arg1: Variant = null,
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null,
	arg6: Variant = null
) -> String:
	var final_msg = convert_to_string(msg)
	var arguments = [arg1, arg2, arg3, arg4, arg5, arg6]
	for arg in arguments:
		if arg != null:
			final_msg += (" " + convert_to_string(arg))
	return final_msg

## Converts [param something] into a string.[br]
## If [param something] is a Dictionary, uses a special way to convert it into a string.[br]
## You can add more exceptions and rules for how different things are converted to strings here.[br]
## Stolen from Loggie
static func convert_to_string(something: Variant) -> String:
	var result: String
	if something is Dictionary:
		result = JSON.new().stringify(something, "  ", false, true)
	else:
		result = str(something)
	return result
