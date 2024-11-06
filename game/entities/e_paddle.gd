## Paddle Entity.
##
## Represents the player's paddle.
## Handles player input for movement and bouncing the ball upon collision.
## When an entity enters its area, it adds a `Bounced` component to that entity with the paddle's normal.
class_name Paddle
extends Entity

@export var normal := Vector2(0, 1)  # Adjust based on your bumper's orientation
## The maximum amonunt the normal is rotated based on the distance from the paddle
@export var max_rot := 33.0

var paddle_width := 100.0
var last_normal:Vector2

func on_ready() -> void:
	Utils.sync_transform(self)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Ball:
		var entity  = body as Ball
		var bounced = Bounced.new()
		var entity_trs = entity.get_component(Transform) as Transform
		var paddle_trs = get_component(Transform) as Transform

		# Calculate the delta vector from paddle to ball
		var half_width = paddle_width / 2.0
		var max_rot_rad = deg_to_rad(max_rot)
		var delta = remap(entity_trs.position.x - paddle_trs.position.x, -half_width, half_width, -max_rot_rad, max_rot_rad)

		# Rotate the normal vector by the calculated angle
		last_normal = normal.rotated(delta)
		bounced.normal = last_normal

		entity.add_component(bounced)
