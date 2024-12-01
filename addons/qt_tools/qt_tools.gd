@tool
extends EditorPlugin

var dock

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	# Load the dock scene and instantiate it.
	dock = preload("tools_dock.tscn").instantiate()

	# Add the loaded scene to the docks.
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	# Note that LEFT_UL means the left of the editor, upper-left dock.

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	# Remove the dock.
	remove_control_from_docks(dock)
	# Erase the control from the memory.
	dock.free()
