## FrictionSystem.
##
## Applies friction to entities by reducing their velocity over time.
## Uses the `Friction` component to determine the friction coefficient.
## Ensures the velocity does not become negative.
class_name FrictionSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([Transform, Velocity, Friction])


func process(entity: Entity, delta: float) -> void:
	var velocity: Velocity = entity.get_component(Velocity)
	var friction: Friction = entity.get_component(Friction)

	# Reduces velocity speed over time based on the friction coefficient
	velocity.speed = max(0, velocity.speed - (friction.coefficient * delta))
