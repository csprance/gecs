#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: Entity
#
#		Helper Class for Developers to quickly attach to a Node to
#		mark it as an Entity.
#
#		Components are automatically added to the Entity in the
#		Framework.
#
#	Remarks:
#
#		This Class, has a number of virtual methods as a convenience to
#		the developer using the Framework.
#
@icon("res://addons/gs_ecs/icons/singleplayer.png")

extends Node

class_name Entity


var id:
	get = _get_id
	
var enabled = true

# virtual calls

func on_init():
	Logger.trace("[entity] on_init")

func on_ready():
	Logger.trace("[entity] on_ready")
	
func on_enter_tree():
	Logger.trace("[entity] on_enter_tree")

func on_exit_tree():
	Logger.trace("[entity] on_exit_tree")

func on_before_add():
	Logger.trace("[entity] on_before_add")

func on_after_add():
	Logger.trace("[entity] on_after_add")

func on_before_remove():
	Logger.trace("[entity] on_before_remove")

func on_after_remove():
	Logger.trace("[entity] on_after_remove")


func add_component(component):
	ECS.entity_add_component(self, component)

func get_component(component_name):
	return ECS.entity_get_component(self.id, component_name)

#
func has_component(component_name):
	return ECS.entity_has_component(self.id, component_name)


func remove_component(component_name):
	ECS.entity_remove_component(self, component_name)


func _get_id():
	return get_instance_id()
	

func _ready():
	Logger.trace("[entity] _ready")
	on_ready()


func _enter_tree():
	Logger.trace("[entity] _enter_tree")

	# add self as an entity
	ECS.add_entity(self)
	on_enter_tree()
	
	
func _exit_tree():
	Logger.trace("[entity] _exit_tree")
	on_exit_tree()


func _init():
	Logger.trace("[entity] _init")
	on_init()
