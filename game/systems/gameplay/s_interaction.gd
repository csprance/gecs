## This system is responsible for handling interactions between entities.
## It runs for every interactor entity and checks if it just made an interaction with another entity.
## If it did it will create the relationships between that entity and the interactor so it is processed by the InteractablesSystem.
## Which is responsible for running the interactions on the interactable entities passing in the interactors.
class_name InteractionSystem
extends System

var r_can_interact_with_anything = Relationship.new(C_CanInteractWith.new(), ECS.wildcard)

func query() -> QueryBuilder:
	return q.with_all([C_Interactor]).with_relationship([r_can_interact_with_anything]).with_none([C_Interacting])


func process(interactor: Entity, delta: float) -> void:
	var e_interactable = interactor.get_relationship(r_can_interact_with_anything).target
	var c_interactable = e_interactable.get_component(C_Interactable) as C_Interactable
	# Check if the interaction should start
	if c_interactable.action.should_start_interaction.call(interactor, delta):
		# Add the being interacted with relationship to the interactable with the interactor
		e_interactable.add_relationship(Relationship.new(C_BeingInteractedWith.new(), interactor))
		# This kicks it over to the interactables system to run the interaction
		# remove the can interact with relationship
		interactor.remove_relationship(r_can_interact_with_anything)
		# specify we're interacting with the interactable
		interactor.add_component(C_Interacting.new())
		
