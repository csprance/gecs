## Observer that watches C_ObserverTest component for add/remove/change events
class_name O_ObserverTest
extends Observer

var added_count: int = 0
var removed_count: int = 0
var changed_count: int = 0
var last_added_entity: Entity = null
var last_removed_entity: Entity = null
var last_changed_entity: Entity = null
var last_changed_property: String = ""
var last_old_value: Variant = null
var last_new_value: Variant = null

func watch() -> Resource:
	return C_ObserverTest

func match() -> QueryBuilder:
	# Match all entities with C_ObserverTest
	return q.with_all([C_ObserverTest])

func on_component_added(entity: Entity, component: Resource) -> void:
	added_count += 1
	last_added_entity = entity

func on_component_removed(entity: Entity, component: Resource) -> void:
	removed_count += 1
	last_removed_entity = entity

func on_component_changed(
	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
) -> void:
	changed_count += 1
	last_changed_entity = entity
	last_changed_property = property
	last_old_value = old_value
	last_new_value = new_value

func reset() -> void:
	added_count = 0
	removed_count = 0
	changed_count = 0
	last_added_entity = null
	last_removed_entity = null
	last_changed_entity = null
	last_changed_property = ""
	last_old_value = null
	last_new_value = null
