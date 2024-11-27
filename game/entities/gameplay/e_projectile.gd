class_name Projectile
extends Entity

func on_ready():
    # Take the C_Transform and sync it with the transform of the entity
    Utils.sync_from_transform(self)