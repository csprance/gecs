## This is the base class for all interactions. An interaction is a special type of action that is triggered through the interaction system.
class_name Interaction
extends Action

## This method should be overidden in your own action to handle the interaction it is called when the interaction is triggered.
## It should return true if the interaction was successful and false if it was not.
func _interaction(interactable: Entity, interactors: Array, meta: Dictionary = {}) -> bool:
    assert(false, "You need to implement the interaction method in your interaction action")
    return false

## This method is called by the interaction system to run the Interaction. It should not be overidden and is used to intercept the interaction and pass it to the interaction method.
## It returns true if the interaction was successful and false if it was not.
func run_interaction(interactable: Entity, interactors: Array, meta: Dictionary = {}) -> bool:
    return _interaction(interactable, interactors, meta)


func run_action(_e=[], _m=[]) -> void:
    assert(false, 'You should instead run the run_interaction for an interaction')