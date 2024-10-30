@tool
extends EditorPlugin

var control

func _enter_tree():
	control = preload("res://addons/repl/control.tscn").instantiate()
	add_control_to_bottom_panel(control, "REPL")


func _exit_tree():
	remove_control_from_bottom_panel(control)
	control.free()
