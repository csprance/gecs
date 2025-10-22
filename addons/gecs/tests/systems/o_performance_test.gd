## Simple observer for performance benchmarking
class_name O_PerformanceTest
extends Observer

var added_count: int = 0
var removed_count: int = 0
var changed_count: int = 0

func watch() -> Resource:
	return C_ObserverTest

func match() -> QueryBuilder:
	return q.with_all([C_ObserverTest])

func on_component_added(entity: Entity, component: Resource) -> void:
	added_count += 1

func on_component_removed(entity: Entity, component: Resource) -> void:
	removed_count += 1

func on_component_changed(
	entity: Entity, component: Resource, property: String, old_value: Variant, new_value: Variant
) -> void:
	changed_count += 1
	# Simulate some processing
	var _val = component.get("value")

func reset_counts():
	added_count = 0
	removed_count = 0
	changed_count = 0
