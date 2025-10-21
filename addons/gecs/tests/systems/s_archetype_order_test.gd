## Test system that verifies component order
class_name ArchetypeOrderTestSystem
extends System

var order_correct = false


func query() -> QueryBuilder:
	# Intentionally reverse order from with_all to test iterate() controls order
	return ECS.world.query.with_all([C_TestA, C_TestB]).iterate([C_TestB, C_TestA])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if components.size() == 2:
		# First should be C_TestB, second should be C_TestA
		var first = components[0][0] if components[0].size() > 0 else null
		var second = components[1][0] if components[1].size() > 0 else null

		if first is C_TestB and second is C_TestA:
			order_correct = true
