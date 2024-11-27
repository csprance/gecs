## This class specifically handles collisions with projectiles
@tool
class_name Hitbox3D
extends Area3D

## What entity this hitbox belongs to
@export var parent: Entity
## What part of the entity this hitbox is
@export var part : String = 'default'


func _on_hitbox_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Projectile:
		pass


func _on_hitbox_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Projectile:
		pass
