
#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: System
#
#	Helper Class for a Developer to add a System process
#	to the ECS Framework.
#
#
@icon("res://addons/gs_ecs/icons/gear.png")

extends Node

class_name System


@export var COMPONENTS = ""
@export var ENABLED = true

var components = ""
var enabled = false

# virtual calls

func on_init():
	Logger.trace("[system] on_init")
	
	
func on_ready():
	Logger.trace("[system] on_ready")
	
	
func on_before_add():
	Logger.trace("[system] on_before_add")
	
	
func on_after_add():
	Logger.trace("[system] on_after_added")
	
	
func on_before_remove():
	Logger.trace("[system] on_before_remove")
	
	
func on_after_remove():
	Logger.trace("[system] on_after_remove")
	
	
func on_process(entities, delta):
	for entity in entities:
		on_process_entity(entity, delta)
	
	
func on_process_entity(entity, delta):
	Logger.trace("[system] on_process_entity")
	pass
	
	
func _ready():
	
	Logger.trace("[system] _ready")
	
	if COMPONENTS:	components = COMPONENTS
	if ENABLED:		enabled = ENABLED
	
	var _components = components.to_lower().split(",")
	ECS.add_system(self, _components)
	
	on_ready()
	
	
func _init():
	Logger.trace("[system] _init")
	on_init()
