@tool
extends Node

func _ready():
    var all_systems = _get_all_systems("res://game/systems")
    var added_systems = []
    for child in get_children():
        added_systems.append(child.name)
    var missing_systems = []
    for system_name in all_systems:
        if not added_systems.has(system_name):
            missing_systems.append(system_name)
    if missing_systems.size() > 0:
        push_warning("Warning: The following systems are missing from the systems node:")
        for system in missing_systems:
            push_warning(" - %s" % system)
    else:
        print("All systems are added.")

func _get_all_systems(path: String):
    var systems = []
    var dir = DirAccess.open(path)
    if DirAccess.open(path):
        dir.list_dir_begin()
        var file_name := dir.get_next()
        while file_name != "":
            if dir.current_is_dir():
                systems += _get_all_systems(file_name.get_base_dir())
            else:
                if file_name.ends_with(".gd"):
                    var system_name = file_name.get_basename()
                    systems.append(system_name)
            file_name = dir.get_next()
        dir.list_dir_end()
    else:
        print("Failed to open directory: %s" % path)
    return systems
