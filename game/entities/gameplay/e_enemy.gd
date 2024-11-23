class_name Enemy
extends Entity

func on_ready():
	# Add the components
	Utils.sync_transform(self)


func _on_interest_dome_body_shape_entered(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		var player_pos = body.global_transform.origin
		Loggie.debug('Something entered an enemies range', player_pos)
		add_component(C_Interested.new(player_pos))
