## Penned Observer.
## When a sheep gets tagged with C_Penned, strip the behavior components so it
## stops wandering or fleeing — it just settles in the pen.
## C_Penned is terminal (never removed), so no paired on_removed handler.
class_name O_Penned
extends Observer


func query() -> QueryBuilder:
	return q.with_all([C_Sheep, C_Penned]).on_added()


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	cmd.remove_component(entity, C_Wander)
	cmd.remove_component(entity, C_Flee)
	cmd.remove_component(entity, C_Velocity)
