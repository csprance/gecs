class_name OpenDoorAction
extends Action

func execute() -> void:
    # Do we have enough keys?
    if GameState.active_item_quantity < 1:
        Loggie.error('Not enough keys to open door')
        return 

    # get the door entity that has an interaction tag on it
    var doors = ECS.world.query.with_all([C_Locked, C_Interactable, C_CanInteractWith, C_Door]).execute()

    # Remove the locked component from the door entity
    for door in doors:
        ## Remove all the things that make it a door
        door.remove_components([C_Locked, C_Interacting, C_CanInteractWith, C_Interactable, C_Door])
        # use up the key that is the active item 
        GameState.use_inventory_item(GameState.active_item)
        Loggie.debug('Opened door', door)