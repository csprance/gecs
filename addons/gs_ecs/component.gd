#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: Component
#
#	Contains the Data for an Entity in the Framework
#
#	Remarks:
#
#		This is a Helper Class to provide a Signature to the Developer
#		and the Framwork that a particular Node is a Component for an
#		Entity.
#
#		By itself, it does not do much without a System that
#		uses the data in it.
#
@icon("res://addons/gs_ecs/icons/menuGrid.png")

extends Node

class_name Component

func on_init():
	Logger.trace("[component] on_init")
	pass
	
	
func on_ready():
	Logger.trace("[component] on_ready")
	pass
	
	
func _enter_tree():
	Logger.trace("[component] _enter_tree")
	
	# find parent entity and register
	var _done = false
	# get first parent node
	var _parent = get_parent()
	
	if _parent == null:
		return
	
	while not _done:
		
		if _parent == null:
			_done = true
			continue
		
		if (_parent is Entity):
			_done = true
			ECS.entity_add_component(_parent, self)
			continue
		# move up the chain
		_parent = _parent.get_parent()
	
	
func _exit_tree():
	Logger.trace("[component] _exit_tree")
	
	
func _ready():
	Logger.trace("[component] _ready")
	on_ready()
	
	
func _init():
	Logger.trace("[component] _init")
	on_init()
	
