@tool
@icon('res://game/assets/icons/gear.svg')
class_name Gear
extends Node3D

@onready var default_skeleton: Skeleton3D = $DefaultSkeleton

var skeleton_path: NodePath


func _ready() -> void:
	# When in game we want to remove the default skeleton and set the external skeleton based on the
	# skeleton path which is set by the [GearSystem]
	# In the editor we want to be able to see the default skeleton
	if not Engine.is_editor_hint():
		remove_child(default_skeleton)
		for child in find_children('*', 'BoneAttachment3D'):
			var bone_attach: BoneAttachment3D = child
			bone_attach.set_external_skeleton(skeleton_path)
			bone_attach.set_use_external_skeleton(true)		
