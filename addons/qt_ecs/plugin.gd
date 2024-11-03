@tool
extends EditorPlugin


func _enter_tree():
    add_autoload_singleton("WorldManager", "res://addons/qt_ecs/world_manager.gd")


func _exit_tree():
    remove_autoload_singleton("WorldManager")
