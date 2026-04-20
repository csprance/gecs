## Picks a new random horizontal direction for every non-fleeing, non-penned
## sheep whenever its C_Wander timer runs out.
class_name WanderSystem
extends System


func query() -> QueryBuilder:
	return (
		q
		.with_all([C_Sheep, C_Wander])
		.with_none([C_Penned])
		.without_relationship([Relationship.new(C_FleeingFrom.new(), null)])
	)


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var wander := entity.get_component(C_Wander) as C_Wander
		wander.time_left -= delta
		if wander.time_left <= 0.0:
			var angle := randf() * TAU
			wander.direction = Vector3(cos(angle), 0.0, sin(angle))
			wander.time_left = randf_range(1.5, 3.5)
