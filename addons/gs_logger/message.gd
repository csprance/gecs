#
#Class: Message
#	Simple representation of a Message to Append to a Logger
#
#Remarks:
#	A Layout will Format a message before it is sent to
#	its assigned Appender.

extends Resource
class_name Message

var level : int
var text : String
var category : String
var line : int
var data


func _init(level : int =000, text : String = "", category : String = "general", line : int = 0, data = {}):
	
	self.level = level
	self.text = text
	self.category = category
	self.line = line
	self.data = data
