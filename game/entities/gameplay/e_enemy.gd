@tool
class_name Enemy
extends Entity

var spawn_spot: Vector3

func on_ready():
	Utils.sync_transform(self)
