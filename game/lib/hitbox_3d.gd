## This class specifically handles collisions with projectiles
@tool
class_name Hitbox3D
extends StaticBody3D

signal hitbox_entered(projectile: Projectile, parent: Entity, part: String)
signal hitbox_exited(projectile: Projectile, parent: Entity, part: String)


## What entity this hitbox belongs to
@export var parent: Entity
## What part of the entity this hitbox is
@export var part : String = 'default'
## The scale of the hitbox collision shape
@export var hitbox_scale := Vector3.ONE:
	get:
		return hitbox_scale
	set(v):
		hitbox_scale = v
		if collision_shape_3d:
			collision_shape_3d.scale = v
@export var debug: bool = true
@export var color: Color = Color(1, 0, 0, 0.5)


## The collision shape of the hitbox
@onready var collision_shape_3d: CollisionShape3D = %CollisionShape3D

func _ready() -> void:
	hitbox_scale = hitbox_scale

func _process(_delta: float) -> void:
	if debug:
		DebugDraw3D.draw_box_xf(collision_shape_3d.global_transform, color)

