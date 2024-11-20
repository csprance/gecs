class_name Player
extends Entity

@onready var visuals :MeshInstance3D = %MeshInstance3D

func on_ready():
	Utils.sync_transform(self)