class_name ActionPicker
extends Resource

@export var actions: Array[Action]

func _pick_action()-> Array[Action]:
    assert(false, "This should be overriden")
    return actions

    
func pick_action() -> Array[Action]:
    assert(actions.size() > 0, "No actions to pick from")
    return _pick_action()