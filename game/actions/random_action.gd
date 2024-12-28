## Chooses a random action to run
class_name RandomAction
extends ActionPicker



func _pick_action()->Array[Action]:
    return [actions[randi() % actions.size()]]