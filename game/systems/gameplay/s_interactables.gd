## This system runs on all the interactables in the game and checks if they are being interacted with. If they are, it will call the interactable's interaction component interact method.
class_name InteractablesSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Interactable]).with_relationship([Relationship.new(C_BeingInteractedWith.new(), ECS.wildcard)])

func process(interactable: Entity, delta: float) -> void:
	var c_interactable = interactable.get_component(C_Interactable) as C_Interactable
	var r_interactors = interactable.get_relationships(Relationship.new(C_BeingInteractedWith.new(), ECS.wildcard))
	# Call the interaction with all the entities interacting with it.
	c_interactable.action.run_interaction.call(interactable, r_interactors.map(func(x): return x.target))
	# Remove the being interacted with relationship
	interactable.remove_relationships(r_interactors)
