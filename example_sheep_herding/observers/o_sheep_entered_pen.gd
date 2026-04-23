## Reacts to the custom &"sheep_entered_pen" event emitted by PenArea3D when a
## sheep body enters a pen's trigger volume. Queues C_Penned on the sheep;
## O_Penned then strips its behavior components in a second reactive step.
class_name O_SheepEnteredPen
extends Observer


func query() -> QueryBuilder:
	return q.with_all([C_Sheep]).with_none([C_Penned]).on_event(&"sheep_entered_pen")


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	cmd.add_component(entity, C_Penned.new())
