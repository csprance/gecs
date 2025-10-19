## This system runs when an entity that is not dead and has it's transform component changed
## This is a simple example of a reactive system that updates the entity's transform ONLY when the transform component changes if it's not dead
class_name TestAObserver
extends Observer


var event_count := 0
var added_count := 0


## The component to watch for changes
func watch() -> Resource:
	return C_TestA


# What the entity needs to match for the system to run
func match() -> QueryBuilder:
	# The query the entity needs to match
	return ECS.world.query.with_none([C_TestB])


# What to do when a property on C_Transform just changed on an entity that matches the query
func on_component_changed(
	entity: Entity, component: Resource, property: String, old_value: Variant, new_value: Variant
) -> void:
	# Set the transfrom from the component to the entity
	print("We changed!", entity.name, component.value)
	event_count += 1
	
func on_component_added(entity: Entity, component: Resource) -> void:
	added_count += 1
