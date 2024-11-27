class_name Enemy
extends Entity

var spawn_spot: Vector3

func on_ready():
	Utils.sync_transform(self)

# Start Chasing
func _on_interest_dome_body_shape_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Started Chasing', body)
		add_component(C_Chasing.new(body))

# Become interested
func _on_interest_dome_body_shape_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Got Interested')
		remove_component(C_Chasing)
		add_component(C_Interested.new(body.global_transform.origin))


func _on_attack_area_body_shape_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Stopped Attacking', body)
		remove_component(C_Attacking)


func _on_attack_area_body_shape_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Player:
		Loggie.debug('Started Attacking', body)
		add_component(C_Attacking.new(body))


func _on_hitbox_area_body_shape_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Projectile:
		Loggie.debug('Projectile Left Hitbox', body)
		var c_projectile = body.get_component(C_Projectile) as C_Projectile
		if c_projectile:
			add_component(C_Damage.new(c_projectile.damage_component.amount))
		body.add_component(C_IsPendingDelete.new())
		

func _on_hitbox_area_body_shape_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body is Projectile:
		Loggie.debug('Projectile Entered Hitbox', body)
		var c_projectile = body.get_component(C_Projectile) as C_Projectile
		if c_projectile:
			add_component(C_Damage.new(c_projectile.damage_component.amount))
		body.add_component(C_IsPendingDelete.new())
