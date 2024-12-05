class_name OpenDoorInteraction
extends Interaction

func interaction(interactable: Entity, interactors: Array[Entity], meta: Dictionary) -> bool:
    # Make sure we're a door. 
    # play an animation to open the door
    interactable.add_component(C_PlayAnimation.new("open"))
    return true
    