#
#Class: HtmlLayout
#	Generates an HTML Page and adds each Log Event
#	to a Row in a Table.
#

class_name HtmlLayout
extends Layout


const LOG_LEVEL_ALL = 999
const LOG_LEVEL_FINE = 700
const LOG_LEVEL_TRACE = 600
const LOG_LEVEL_DEBUG = 500
const LOG_LEVEL_INFO = 400
const LOG_LEVEL_WARN = 200
const LOG_LEVEL_ERROR = 100
const LOG_LEVEL_FATAL = 001
const LOG_LEVEL_NONE = 000


var contextual_classes = \
	{
		LOG_LEVEL_ALL: 	"",
		LOG_LEVEL_FINE: 	"",
		LOG_LEVEL_TRACE: "",
		LOG_LEVEL_INFO: 	"info",
		LOG_LEVEL_FATAL: "danger",
		LOG_LEVEL_WARN: 	"warning",
		LOG_LEVEL_ERROR: "danger",
		LOG_LEVEL_DEBUG: "",
		LOG_LEVEL_NONE: 	"",
	}

var header = \
"""
<html>
<head>
<title>Message Log</title>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
</head>
<body>
<div class="container">
<h2>Godot Logger</h2>
<table class="table table-condensed table-hover">
<thead>
<th>Number</th>
<th>Message</th>
</thead>
"""


var footer = \
"""
</table>
</body>
</html>
"""

func get_header():
	return header


func get_footer():
	return footer


func build(message: Message, format: int):
	return '<tr class="%s"><td style="width:100px"><span class="glyphicon glyphicon-edit" style="padding-right:10px"></span><span>%d</span></td><td>%s</td></tr>' % [contextual_classes[message.level], message.line, message.text]
