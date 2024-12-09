@tool
class_name Enemy
extends Entity

var spawn_spot: Vector3

func on_ready():
	Utils.sync_transform(self)


func _on_visible_on_screen_enabler_3d_screen_entered() -> void:
	ECS.world.enable_entity(self)


func _on_visible_on_screen_enabler_3d_screen_exited() -> void:
	ECS.world.disable_entity(self)
