## Capture the balls and sticks it on the first active paddle
class_name BallCaptureSystem
extends System


func query():
	return q.with_all([C_ActiveBall, C_Transform, C_Captured]) # add required components


func process(entity: Entity, _delta: float) -> void:
	# remove the velocity component
	entity.remove_components([C_Velocity, C_Friction, C_Bounced])

	# Put the ball above the paddles transform
	var ball_trs = entity.get_component(C_Transform) as C_Transform
	var active_paddles = ECS.world.query.with_all([C_ActivePaddle]).execute() as Array[Entity]
	if active_paddles.size() > 0:
		var paddle_trs = active_paddles[0].get_component(C_Transform) as C_Transform
		ball_trs.position = paddle_trs.position + (Vector2.UP * 50.2)
