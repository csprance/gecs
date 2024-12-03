## PhysicsSystem.(Simple Physics)
##
## Updates entities' positions based on their velocity.
## Processes entities with `Velocity` and `Transform` components.
## Calculates movement and updates the `Transform` component.
class_name PhysicsSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Transform, C_Physics]).with_none([C_CharacterBody3D])


func process_all(entities: Array, delta: float):
	var velocitys = ECS.get_components(entities, C_Velocity) as Array[C_Velocity]
	var transforms = ECS.get_components(entities, C_Transform) as Array[C_Transform]
	for i in range(entities.size()):
		# Normalize direction to prevent speed inconsistencies
		transforms[i].transform.origin += velocitys[i].direction.normalized() * velocitys[i].speed * delta