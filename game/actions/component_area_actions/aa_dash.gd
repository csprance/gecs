class_name DashInAreaAction
extends ComponentAreaAction

@export var dash_speed: float = 1.5
@export var dash_duration: float = 0.5
@export var dash_cooldown: float = 1.0

func query() -> QueryBuilder:
	return ECS.world.query.with_any([C_Player])

# Dash towards the  body if we get in the area
func on_enter(parent: Entity, target: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	Loggie.debug('Started Dashing!')
	parent.add_component(C_Dashing.new())

# Stop dashing towards 
func on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	Loggie.debug('Stopped Dashing')
	parent.remove_component(C_Dashing)

