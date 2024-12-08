## this plays an animation on the searchable and drops the specified item
class_name OpenSearchableInteraction
extends Interaction

func _interaction(interactable: Entity, interactors: Array, meta: Dictionary = {}) -> bool:
    # Make sure we're a door. 
    # play an animation to open the door
    interactable.add_component(C_PlayAnimation.new("open"))
    for i in interactors:
        i.remove_component(C_Interacting)
    # searchables only work once
    interactable.remove_component(C_Interactable)
    # drop the item
    
    return true