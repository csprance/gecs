## FrictionSystem.
##
## Applies friction to entities by reducing their velocity over time.
## Uses the `Friction` component to determine the friction coefficient.
## Ensures the velocity does not become negative.
class_name FrictionSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Friction]).with_any([C_Rotvel])


func process(entity: Entity, delta: float) -> void:
	var velocity = entity.get_component(C_Velocity) as C_Velocity
	var friction = entity.get_component(C_Friction) as C_Friction

	# Reduces velocity speed over time based on the friction coefficient
	velocity.speed = max(0, velocity.speed - (friction.coefficient * delta))
