class_name Powerup
extends Entity

func on_ready():
    add_components([C_Transform, C_Physics, C_Velocity, C_Powerup])
    Utils.sync_transform(self)