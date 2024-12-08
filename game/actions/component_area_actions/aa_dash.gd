## We define a dash as a movement action that moves the entity towards a target at a high speed for a short duration with no chasing behavior
## So wherever it sees the target is it launches at that and when it reaches it, it stops and chases
class_name DashInAreaAction
extends ComponentAreaAction

@export var dash_speed: float = 5.0
@export var dash_duration: float = 3.0
@export var dash_cooldown: float = 8.0


# Dash towards the  body if we get in the area
func on_enter(parent: Entity, target: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	# if we're already dashing don't dash
	if parent.has_component(C_Dashing):
		return
	Loggie.debug('Started Dashing!')
	parent.add_component(C_Dashing.new(dash_speed, dash_cooldown))

# Stop dashing towards 
func on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	pass
	# Loggie.debug('Stopped Dashing')
	# parent.remove_component(C_Dashing)
