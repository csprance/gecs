class_name MainMenu
extends Ui

@onready var pasword_input: LineEdit = %PasswordInput
@onready var pasword_screen: Control = %PasswordScreen
@onready var menu_screen: Control = %MenuScreen


# Start the game
func _on_start_clicked(_meta:Variant) -> void:
	var level = Constants.level_by_password(pasword_input.text)
	if level:
		LevelUtils.load_level(level)
		return
	assert(level, "No level found for password: " + pasword_input.text)

# Show the password input
func _on_password_clicked(meta:Variant) -> void:
	pasword_screen.visible = not pasword_screen.visible
	menu_screen.visible = not menu_screen.visible
