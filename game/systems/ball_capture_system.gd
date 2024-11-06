## Capture the balls and sticks it on the first active paddle
class_name BallCaptureSystem
extends System


func query(q: QueryBuilder):
	return q.with_all([ActiveBall, Transform, Captured]) # add required components


func process(entity: Entity, delta: float) -> void:
	# remove the velocity component
	entity.remove_component(Velocity)
	entity.remove_component(Friction)

	# Put the ball above the paddles transform
	var ball_trs = entity.get_component(Transform) as Transform
	var active_paddles = ECS.buildQuery().with_all([ActivePaddle]).execute() as Array[Entity]
	if active_paddles.size() > 0:
		var paddle_trs = active_paddles[0].get_component(Transform) as Transform
		ball_trs.position = paddle_trs.position + (Vector2.UP * 50.2)
