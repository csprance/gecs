@tool
class_name Enemy
extends Entity

func on_ready():
	Utils.sync_transform(self)
