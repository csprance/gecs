class_name DashInAreaAction
extends ComponentAreaAction

@export var dash_speed: float = 5.0
@export var dash_duration: float = 0.5
@export var dash_cooldown: float = 1.0


# Dash towards the  body if we get in the area
func on_enter(parent: Entity, target: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	# if we're already dashing don't dash
	if parent.has_component(C_Dashing):
		return
	Loggie.debug('Started Dashing!')
	parent.add_component(C_Dashing.new(dash_speed, dash_duration, dash_cooldown))

# Stop dashing towards 
func on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	pass
	# Loggie.debug('Stopped Dashing')
	# parent.remove_component(C_Dashing)

