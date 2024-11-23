class_name Enemy
extends Entity

var spawn_spot: Vector3

func on_ready():
	# Add the components
	Utils.sync_transform(self)

# Start Chasing
func _on_interest_dome_body_shape_entered(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Started Chasing', body)
		add_component(C_Chasing.new(body))

# Become interested
func _on_interest_dome_body_shape_exited(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		var player_pos = body.global_transform.origin
		Loggie.debug('Got Interested', player_pos)
		remove_component(C_Chasing)
		add_component(C_Interested.new(player_pos))
