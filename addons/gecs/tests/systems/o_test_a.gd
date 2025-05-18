## This system runs when an entity that is not dead and has it's transform component changed
## This is a simple example of a reactive system that updates the entity's transform ONLY when the transform component changes if it's not dead
class_name TestAObserver
extends Observer


## The component to watch for changes
func watch() -> Resource:
	return C_Transform


# What the entity needs to match for the system to run
func match() -> QueryBuilder:
	# The query the entity needs to match
	return q.with_none([C_Death])  # Dead Things are not updated


# What to do when a property on C_Transform just changed on an entity that matches the query
func on_component_changed(
	entity: Entity, component: Resource, property: String, old_value: Variant, new_value: Variant
) -> void:
	# Set the transfrom from the component to the entity
	entity.global_transform = component.transform
