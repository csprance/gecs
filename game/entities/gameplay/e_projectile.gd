class_name Projectile
extends Entity

## This is used to check the actual projectile collision it is resized in [method WeaponUtils.instantiate_projectile]
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
## This is used to find all bodies in the explosion radius 
@onready var explosion_radius: Area3D = %ExplosionRadius
## This is the size of the explosion radius mapped onto a collision shape 3d it is resized in [method WeaponUtils.instantiate_projectile]
@onready var explosion_radius_shape_3d: CollisionShape3D = %ExplosionRadiusShape3D


func on_ready():
	# Take the C_Transform and sync it with the transform of the entity
	Utils.sync_from_transform(self)
