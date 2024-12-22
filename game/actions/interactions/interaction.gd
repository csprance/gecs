## This is the base class for all interactions. An interaction is a special type of action that is triggered through the interaction system.
class_name Interaction
extends Action

enum InteractionMode {
	PRESS,
	HOLD,
	RAPID_PRESS
}

@export var interaction_mode := InteractionMode.PRESS

## This method should be overidden in your own action to handle the interaction it is called when the interaction is triggered.
## It should return true if the interaction was successful and false if it was not.
func _interaction(interactable: Entity, interactors: Array, meta: Dictionary = {}) -> bool:
	assert(false, "You need to implement the interaction method in your interaction action")
	return false

## This method is called by the interaction system to run the Interaction. It should not be overidden and is used to intercept the interaction and pass it to the interaction method.
## It returns true if the interaction was successful and false if it was not.
func run_interaction(interactable: Entity, interactors: Array, meta: Dictionary = {}) -> bool:
	for interactor in interactors:
		interactor.remove_component(C_Interacting)
	return _interaction(interactable, interactors, meta)

## This method is called by the interaction system to see if the interaction should execute
## It generally checks if the interact button was pressed and if the interaction mode is correct.
func should_start_interaction(interactor: Entity, delta: float) -> bool:
	if Input.is_action_just_pressed("interact"):
		if interaction_mode == InteractionMode.PRESS:
			return true
	return false

func run_action(_e=[], _m=[]) -> void:
	assert(false, 'You should instead run the run_interaction for an interaction')