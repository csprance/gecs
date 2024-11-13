## Handles collisions with bricks.
class_name BrickCollisionSystem
extends System

func query():
	return q.with_all([C_BrickCollision])

func process(entity, _delta):
	var brick_collision = entity.get_component(C_BrickCollision).collision
	var collider = brick_collision.get_collider()
	
	if entity is Ball:
		# The thing we collided with takes damage based on the damage output component
		var damage = C_Damage.new()
		var damage_output = entity.get_component(C_DamageOutput)
		damage.amount = damage_output.value
		collider.add_component(damage)
	
	entity.remove_component(C_BrickCollision)
