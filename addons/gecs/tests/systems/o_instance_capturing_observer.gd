## Test observer that captures the removed component instance for OBS-02 assertions.
## Tracks call counts for correctness (OBS-01) and absence checks (OBS-03).
class_name O_InstanceCapturingObserver
extends Observer

var removed_count: int = 0
var changed_count: int = 0
var last_removed_component: Resource = null

func watch() -> Resource:
	return C_ObserverTest

func on_component_removed(entity: Entity, component: Resource) -> void:
	removed_count += 1
	last_removed_component = component

func on_component_changed(
	entity: Entity, component: Resource, property: String,
	new_value: Variant, old_value: Variant
) -> void:
	changed_count += 1

func reset() -> void:
	removed_count = 0
	changed_count = 0
	last_removed_component = null
