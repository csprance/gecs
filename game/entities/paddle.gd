class_name Paddle
extends Entity

@export var normal := Vector2(0, 1)  # Adjust based on your bumper's orientation


func on_ready() -> void:
	Utils.sync_transform(self)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Entity:
		var entity  = body as Entity
		var bounced = Bounced.new()
		bounced.normal = normal

		entity.add_component(bounced)
