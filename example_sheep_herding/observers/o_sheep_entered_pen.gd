## Reacts to the custom &"sheep_entered_pen" event emitted by PenArea3D when a
## sheep body enters a pen's trigger volume. Tags the sheep with C_Penned
## carrying the pen's center and radius — WanderSystem then picks new wander
## goals inside that area instead of around the sheep, so the sheep naturally
## drifts toward the middle and stays. FleeSystem excludes C_Penned so the
## shepherd can't scare a penned sheep back out.
class_name O_SheepEnteredPen
extends Observer


func query() -> QueryBuilder:
	return q.with_all([C_Sheep]).with_none([C_Penned]).on_event(&"sheep_entered_pen")


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var pen := payload as Pen
	if pen == null:
		return
	var c_pen := pen.get_component(C_Pen) as C_Pen
	var c_penned := C_Penned.new()
	c_penned.center = pen.global_position
	c_penned.radius = c_pen.radius if c_pen else 0.0
	cmd.add_component(entity, c_penned)
	if entity.has_component(C_Flee):
		cmd.remove_component(entity, C_Flee)
	# Drop the current wander target — otherwise the sheep would walk back out
	# of the pen toward its previous goal. Zeroing forces WanderSystem to pick
	# a fresh in-pen goal next tick.
	var c_wander := entity.get_component(C_Wander) as C_Wander
	if c_wander:
		c_wander.target = Vector3.ZERO
		c_wander.time_left = 0.0
