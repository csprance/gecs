
#
#Class: Layout
#	Formats a Log Event for an Appender.
#

class_name Layout
extends Resource

func get_header():
	return ""


func get_footer():
	return ""


func build(message: Message, format: int): 
	return message


func _init():
	pass
