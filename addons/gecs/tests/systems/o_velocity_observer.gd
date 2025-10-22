## Observer approach for velocity-based movement (reactive)
class_name O_VelocityObserver
extends Observer

var process_count: int = 0

func watch() -> Resource:
	return C_TestVelocity

func match() -> QueryBuilder:
	return q.with_all([C_TestPosition, C_TestVelocity])

func on_component_changed(
	entity: Entity, component: Resource, property: String, old_value: Variant, new_value: Variant
) -> void:
	if property == "velocity":
		process_count += 1
		# React to velocity changes by updating position
		var pos = entity.get_component(C_TestPosition)
		if pos:
			# Example: Could apply immediate velocity change
			# In reality, observers are better for reactions than continuous updates
			pass

func on_component_added(entity: Entity, component: Resource) -> void:
	process_count += 1

func reset_count():
	process_count = 0
