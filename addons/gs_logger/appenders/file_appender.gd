#
#Class: FileAppender
#	Logs an Event to a File.
#

class_name FileAppender
extends Appender

var savefile


func append(message : Message):
	savefile.store_string(layout.build(message, logger_format))
	savefile.store_string("\n")


func append_raw(text : String):
	savefile.store_string(text)
	savefile.store_string("\n")


func stop():
	savefile.flush()


func _init(filename : String ="%s.log" % ProjectSettings.get("application/config/name")):
	var _filename = "%s" % [filename]
	savefile = FileAccess.open(_filename, FileAccess.WRITE)
	name = "file appender"
	print("** File Appender Initialized **")
	print(" ")
