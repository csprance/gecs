## Observer that watches C_ObserverHealth component with a query filter
class_name O_HealthObserver
extends Observer

var health_changed_count: int = 0
var health_added_count: int = 0
var health_removed_count: int = 0
var low_health_alerts: Array[Entity] = []

func watch() -> Resource:
	return C_ObserverHealth

func match() -> QueryBuilder:
	# Only watch entities that have both C_ObserverHealth and C_ObserverTest
	return q.with_all([C_ObserverHealth, C_ObserverTest])

func on_component_added(entity: Entity, component: Resource) -> void:
	health_added_count += 1

func on_component_removed(entity: Entity, component: Resource) -> void:
	health_removed_count += 1

func on_component_changed(
	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
) -> void:
	if property == "health":
		health_changed_count += 1
		# Track entities with low health
		if new_value < 30:
			if not low_health_alerts.has(entity):
				low_health_alerts.append(entity)

func reset() -> void:
	health_changed_count = 0
	health_added_count = 0
	health_removed_count = 0
	low_health_alerts.clear()
