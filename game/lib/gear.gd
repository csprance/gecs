@tool
@icon('res://game/assets/icons/gear.svg')
class_name Gear
extends Node3D

@onready var default_skeleton: Skeleton3D = $DefaultSkeleton

var skeleton_path: NodePath


func _ready() -> void:
	remove_child(default_skeleton)
	for child in find_children('*', 'BoneAttachment3D'):
		var bone_attach: BoneAttachment3D = child
		bone_attach.set_external_skeleton(skeleton_path)
		bone_attach.set_use_external_skeleton(true)		
