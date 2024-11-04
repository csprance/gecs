## A Component is just a data container.
## Godot already has data containers and they're called resources
## So we'll just extend from Resource!
@icon('res://addons/qt_ecs/assets/component.svg')
class_name Component
extends Resource

## All Components have a key that is the same across all components of the same type
var key: String


func _init():
    key = get_script().resource_path
