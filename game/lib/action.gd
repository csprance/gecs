class_name Action
extends Resource

@export var callable: Callable = _default_action

func _default_action() -> void:
    Loggie.debug('Default Callable Action') 


func execute() -> void:
    if callable:
        callable.call()