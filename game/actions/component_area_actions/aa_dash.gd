## We define a dash as a movement action that moves the entity towards a target at a high speed for a short duration with no chasing behavior
## So wherever it sees the target is it launches at that and when it reaches it, it stops and chases
class_name DashInAreaAction
extends ComponentAreaAction

@export var dash_duration: float = 3.0
@export var dash_cooldown: float = 8.0


# Dash towards the  body if we get in the area
func _on_enter(parent: Entity, target: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	# if we're already dashing or in cool down don't dash
	if parent.has_component(C_Dashing) or parent.has_component(C_DashCooldown):
		return
	Loggie.debug('Started Dashing!')
	var parent_pos = parent.get_component(C_Transform).transform.origin
	var target_pos = target.get_component(C_Transform).transform.origin

	parent.add_component(C_Dashing.new(parent_pos, target_pos, dash_duration, dash_cooldown))