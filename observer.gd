## An Observer is like a system that changes when a specific event happens
## It also has a query that is used to filter the entities that are processed by the system
## So we can respond to components changes on specific sets of entities
@icon("res://addons/gecs/assets/observer.svg")
class_name Observer
extends Node

## The [QueryBuilder] object exposed for conveinence to use in the system and to create the query.
var q: QueryBuilder


## Override this method and return a [QueryBuilder] to define the required [Component]s the entity
## must match for the system to run. If empty this will match all [Entity]s [br]
func match() -> QueryBuilder:
	return q


## Override this method and provide a single component to watch for events[br]
## This means that the system will only react to events on this component (add/remove/update)[br]
## assuming the entity matches the query defined in the [match()] method.[br]
func watch() -> Resource:
	assert(false, "You must override the watch() method in your system")
	return


## Override this method to define the main processing function for the reactive system when a component is added to an [Entity].[br]
## [param entity] The [Entity] the component was added to.[br]
## [param component] The [Component] that was added. Guaranteed to be the component defined in [method ReactiveSystem.watch].[br]
func on_component_added(entity: Entity, component: Resource) -> void:
	pass


## Override this method to define the main processing function for the reactive system when a component is removed from an [Entity].[br]
## [param entity] The [Entity] the component was added to.[br]
## [param component] The [Component] that was removed. Guaranteed to be the component defined in [method ReactiveSystem.watch].[br]
func on_component_removed(entity: Entity, component: Resource) -> void:
	pass


## Override this method to define the main processing function for the system.[br]
## [param entity] The [Entity] the component that changed is attached to.[br]
## [param component] The [Component] that was removed. Guaranteed to be the component defined in [method ReactiveSystem.watch].[br]
## [param property] The name of the property that changed on the [Component].[br]
## [param old_value] The old value of the property.[br]
## [param new_value] The new value of the property.[br]
func on_component_changed(
	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
) -> void:
	pass
