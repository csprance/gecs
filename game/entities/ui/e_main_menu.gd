class_name MainMenu
extends Ui

@export var worlds : Array[PackedScene]


func _on_start_clicked(meta:Variant) -> void:
	# Purge the current world
	ECS.world.purge()

	# Start the first level
	var world = worlds[0].instantiate()
	world.name = "First World"
	# Add the new world to the scene
	get_tree().root.get_node('./Root').add_child(world)
	# Set it as the active ECS world
	ECS.world = world as World


func _on_password_clicked(meta:Variant) -> void:
	pass # Replace with function body.
