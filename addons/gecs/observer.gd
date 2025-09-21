## An Observer is like a system that reacts when specific component events happen
## It has a query that filters which entities are monitored for these events
## Observers can respond to component add/remove/change events on specific sets of entities
##
## [b]Important:[/b] For property changes to trigger [method on_component_changed], you must
## manually emit the [signal Component.property_changed] signal from within your component.
## Simply setting properties does not automatically trigger observers.
##
## [b]Example of triggering property changes:[/b]
## [codeblock]
## # In your component class
## class_name MyComponent
## extends Component
##
## @export var health: int = 100 : set = set_health
##
## func set_health(new_value: int):
##     var old_value = health
##     health = new_value
##     # This is required for observers to detect the change
##     property_changed.emit(self, "health", old_value, new_value)
## [/codeblock]
@icon("res://addons/gecs/assets/observer.svg")
class_name Observer
extends Node

## The [QueryBuilder] object exposed for conveinence to use in the system and to create the query.
var q: QueryBuilder


## Override this method and return a [QueryBuilder] to define the required [Component]s the entity[br]
## must match for the observer to trigger. If empty this will match all [Entity]s
func match() -> QueryBuilder:
	return q


## Override this method and provide a single component to watch for events.[br]
## This means that the observer will only react to events on this component (add/remove/change)[br]
## assuming the entity matches the query defined in the [method match] method
func watch() -> Resource:
	assert(false, "You must override the watch() method in your system")
	return


## Override this method to define the main processing function for the observer when a component is added to an [Entity].[br]
## [param entity] The [Entity] the component was added to.[br]
## [param component] The [Component] that was added. Guaranteed to be the component defined in [method watch].[br]
func on_component_added(entity: Entity, component: Resource) -> void:
	pass


## Override this method to define the main processing function for the observer when a component is removed from an [Entity].[br]
## [param entity] The [Entity] the component was removed from.[br]
## [param component] The [Component] that was removed. Guaranteed to be the component defined in [method watch].[br]
func on_component_removed(entity: Entity, component: Resource) -> void:
	pass


## Override this method to define the main processing function for property changes.[br]
## This method is called when a property changes on the watched component.[br]
## [br]
## [b]Note:[/b] This method only triggers when the component explicitly emits its
## [signal Component.property_changed] signal for performance reasons. Setting properties directly will
## [b]not[/b] automatically trigger this method.[br]
## [br]
## [param entity] The [Entity] the component that changed is attached to.
## [param component] The [Component] that changed. Guaranteed to be the component defined in [method watch].
## [param property] The name of the property that changed on the [Component].
## [param old_value] The old value of the property.
## [param new_value] The new value of the property.
func on_component_changed(
	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
) -> void:
	pass
