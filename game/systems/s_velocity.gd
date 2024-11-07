## VelocitySystem.
##
## Updates entities' positions based on their velocity.
## Processes entities with `Velocity` and `Transform` components.
## Calculates movement and updates the `Transform` component.
class_name VelocitySystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Velocity, C_Transform])


func process(entity: Entity, delta: float):
	var velocity: C_Velocity   = entity.get_component(C_Velocity)
	var transform: C_Transform = entity.get_component(C_Transform)

	# Calculate velocity as a vector and apply movement
	var velocity_vector: Vector2 = velocity.direction.normalized() * velocity.speed
	transform.position += velocity_vector * delta
