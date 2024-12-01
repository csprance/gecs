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
		# Reduces velocity speed over time based on the friction coefficient
		velocitys[i].speed = max(0, velocitys[i].speed - (frictions[i].coefficient * delta))
