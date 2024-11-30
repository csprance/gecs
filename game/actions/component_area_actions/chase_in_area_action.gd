class_name ChaseInAreaAreaAction
extends ComponentAreaAction

# Start chaing the body if they get in the interest area
func on_enter(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if body is Player:
		Loggie.debug('Started Chasing', body)
		parent.add_component(C_Chasing.new(body))

# Stop chasing the body if they get out of the interest area and become interested in the last position
func on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if body is Player:
		Loggie.debug('Stopped Chasing', body)
	if parent.has_component(C_Chasing):
		parent.remove_component(C_Chasing)
		Loggie.debug('Interested in position now', body.global_transform.origin)
		parent.add_component(C_Interested.new(body.global_transform.origin))
		parent.add_component(C_LookAt.new(body.global_transform.origin))