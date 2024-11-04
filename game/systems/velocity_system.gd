## VelocitySystem.
##
## Updates entities' positions based on their velocity.
## Processes entities with `Velocity` and `Transform` components.
## Calculates movement and updates the `Transform` component.
class_name VelocitySystem
extends System

func _init():
	required_components = [Velocity, Transform]


func process(entity: Entity, delta: float):
	var velocity: Velocity   = entity.get_component(Velocity)
	var transform: Transform = entity.get_component(Transform)

	# Calculate velocity as a vector and apply movement
	var velocity_vector: Vector2 = velocity.direction.normalized() * velocity.speed
	transform.position += velocity_vector * delta
