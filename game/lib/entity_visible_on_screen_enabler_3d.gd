extends VisibleOnScreenEnabler3D


func _on_screen_exited() -> void:
	ECS.world.disable_entity(get_node(enable_node_path))

func _on_screen_entered() -> void:
	ECS.world.enable_entity(get_node(enable_node_path))