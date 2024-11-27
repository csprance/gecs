class_name Enemy
extends Entity

var spawn_spot: Vector3

func on_ready():
	Utils.sync_transform(self)


# Start Chasing the body if we get in the interest area
func _on_interest_area_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Started Chasing', body)
		add_component(C_Chasing.new(body))

# Become interested in the last position of the body
func _on_interest_area_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Got Interested')
		remove_component(C_Chasing)
		add_component(C_Interested.new(body.global_transform.origin))

# Start attacking the body if we get in the attack area
func _on_attack_area_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Started Attacking', body)
		add_component(C_Attacking.new(body))

# Stop attacking the body if we get out of the attack area
func _on_attack_area_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Stopped Attacking', body)
		remove_component(C_Attacking)

