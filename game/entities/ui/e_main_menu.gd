class_name MainMenu
extends Ui

@onready var pasword_input: TextEdit = %PasswordInput
@onready var pasword_screen: Control = %PasswordScreen
@onready var menu_screen: Control = %MenuScreen


# Start the game
func _on_start_clicked(_meta:Variant) -> void:
	load_level(pasword_input.text)

# Show the password input
func _on_password_clicked(meta:Variant) -> void:
	pasword_screen.visible = not pasword_screen.visible
	menu_screen.visible = not menu_screen.visible


func load_level(password:String) -> void:
	# Purge the current world
	ECS.world.purge()
	var level: LevelResource = Constants.level_by_password(password)
	# Start the level
	var world = level.packed_scene.instantiate()
	world.name = level.name
	# Add the new world to the scene
	get_tree().root.get_node('./Root').add_child(world)
	# Set it as the active ECS world
	ECS.world = world as World
