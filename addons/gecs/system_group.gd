## This is a node that automatically fills in the [member System.group] property
## of any [System] that is a child of this node.
## Allowing you to visually organize your systems in the scene tree
## without having to manually set the group property on each [System].
## Add this node to your scene tree and make [System]s children of it.
## The name of the SystemGroup node will be set to [member System.group] for
## all child [System]s.
@tool
@icon('res://addons/gecs/assets/system_folder.svg')
class_name SystemGroup
extends Node

## Put the [System]s in the group based on the [member Node.name] of the [SystemGroup]
@export var auto_group := true

## called when the node enters the scene tree for the first time.
func _enter_tree() -> void:
	# Connect signals
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
	
	# Set the group for all child systems
	if auto_group:
		for child in get_children():
			if child is System:
				child.group = name

## Anytime  a child enters the tree, set its group if it's a System
func _on_child_entered_tree(node: Node) -> void:
	if auto_group:
		if node is System:
			node.group = name
