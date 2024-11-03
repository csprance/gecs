@icon('res://addons/qt_ecs/assets/system.svg')
class_name System
extends Node

## The list list of Components that an Entity must posses all of to run on
var required_components: Array[Variant] = []

## The process function is what runs the processing code
## for this system on each frame.
func process(entity: Entity, delta: float) -> void:
	pass
