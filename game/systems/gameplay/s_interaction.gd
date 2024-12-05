## This system is responsible for handling interactions between entities.
## It runs for every interactor entity and checks if it just made an interaction with another entity.
## If it did it will create the relationships between that entity and the interactor so it is processed by the InteractablesSystem.
## Which is responsible for running the interactions on the interactable entities passing in the interactors.
class_name InteractionSystem
extends System


func query() -> QueryBuilder:
    return q.with_all([C_Interactor]).with_relationship([Relationship.new(C_CanInteractWith.new(), ECS.wildcard)]).with_none([C_Interacting])


func process(interactor: Entity, delta: float) -> void:
    # if the interactor pressed the interact button start the interaction process
    if Input.is_action_just_pressed('interact'):
        # Get all the entities that the interactor can interact with
        var r_interactables = interactor.get_relationships(Relationship.new(C_CanInteractWith.new(), ECS.wildcard))
        for r in r_interactables:
            var interactable = r.target
            # Add the being interacted with relationship to the interactable with the interactor
            interactable.add_relationship(Relationship.new(C_BeingInteractedWith.new(), interactor))
            # This kicks it over to the interactables system to run the interaction
            # remove the can interact with relationship
            interactor.remove_relationship(r)
            interactor.add_component(C_Interacting.new())
    
    
