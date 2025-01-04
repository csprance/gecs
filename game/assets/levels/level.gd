## A level can contain a collection of entities, props, and sysystems and can be loaded and unloaded
@icon('res://game/assets/icons/place.svg')
class_name Level
extends Node

@export var level_name:= ""
@export var tag_line:= ""


@onready var navigation: Node = %Navigation
@onready var entities: Node = %Entities
@onready var systems: Node = %Systems
@onready var props: Node = %Props
