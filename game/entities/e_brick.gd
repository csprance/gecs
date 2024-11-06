## Brick Entity.
##
## Represents a destructible brick in the game.
## Handles collision with the ball and applies damage when hit.
## Contains components for health and handles bounce behavior.
class_name Brick
extends Entity

@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D


# Assuming the Brick has a CollisionShape2D for collision
func on_ready() -> void:
	Utils.sync_transform(self)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Ball:
		var ball = body as Ball

		# Determine the impact point and direction for the bounce
		var normal = global_transform.y.normalized()

		# Create and add the bounce component to the Ball with the calculated normal
		var bounced = Bounced.new()
		bounced.normal = normal
		ball.add_component(bounced)

		# Do damage to the brick
		var damage = Damage.new()
		damage.amount = 1
		add_component(damage)
#
		## give a reward to the player
		#var reward = Reward.new(10) as Reward
		#ball.add_component(reward)
