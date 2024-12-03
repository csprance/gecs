## FrictionSystem.
##
## Applies friction to entities by reducing their velocity over time.
## Uses the `Friction` component to determine the friction coefficient.
## Ensures the velocity does not become negative.
class_name FrictionSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Friction])


func process_all(entities: Array, delta: float):
	var velocitys = ECS.get_components(entities, C_Velocity) as Array[C_Velocity]
	var frictions = ECS.get_components(entities, C_Friction) as Array[C_Friction]
	for i in range(entities.size()):
		 # Reduce the velocity magnitude based on the friction coefficient
		var speed = velocitys[i].velocity.length()
		var friction = frictions[i].coefficient * delta
		var new_speed = max(0, speed - friction)
		if speed > 0:
			velocitys[i].velocity = velocitys[i].velocity.normalized() * new_speed
