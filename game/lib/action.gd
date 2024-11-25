class_name Action
extends Resource

@export var meta = {
    
}

## Always Override this with your own 
func execute() -> void:
    Loggie.warn('Default Action executed. You Should Probably Replace this!!')