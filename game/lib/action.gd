class_name Action
extends Resource

## Meta Data for the Action
@export var meta = {
    'name': 'Default Action',
    'description': 'This is the default action that is executed when no other action is assigned',
}

## Always Override this with your own 
func execute() -> void:
    Loggie.warn('Default Action executed. You Should Probably Replace this!!')