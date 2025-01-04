@tool
class_name Enemy
extends Entity

func on_ready():
	Utils.sync_transform(self)
	var c_lives = get_component(C_Lives) as C_Lives
	if c_lives.respawn_location == Transform3D.IDENTITY:
		var c_trs = get_component(C_Transform) as C_Transform
		c_lives.respawn_location = c_trs.transform
