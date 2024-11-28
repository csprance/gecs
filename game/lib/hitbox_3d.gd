## This class specifically handles collisions with projectiles
@tool
class_name Hitbox3D
extends Area3D

signal hitbox_entered(projectile: Projectile, parent: Entity, part: String)
signal hitbox_exited(projectile: Projectile, parent: Entity, part: String)


## What entity this hitbox belongs to
@export var parent: Entity
## What part of the entity this hitbox is
@export var part : String = 'default'
## The scale of the hitbox collision shape
@export var hitbox_scale: Vector3 :
	get:
		return collision_shape_3d.scale
	set(v):
		if collision_shape_3d:
			collision_shape_3d.scale = v
@export var debug: bool = true
@export var color: Color = Color(1, 0, 0, 0.5)


## The collision shape of the hitbox
@onready var collision_shape_3d: CollisionShape3D = %CollisionShape3D

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and debug:
		DebugDraw3D.draw_box_xf(collision_shape_3d.global_transform, color)

# When Something enteres the hitbox
func _on_hitbox_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Projectile:
		hitbox_entered.emit(body, parent, part)

func _on_hitbox_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Projectile:
		hitbox_exited.emit(body, parent, part)
