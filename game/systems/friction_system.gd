## This is the Friction System it is reponsible for reducing the velocity Component
## based on the Friction Coeffecnient set in the Friction Component
class_name FrictionSystem
extends System

func _init():
	required_components = [Transform, Velocity, Friction]

func process(entity: Entity, delta: float) -> void:
	var velocity: Velocity = entity.get_component(Velocity)
	var friction: Friction = entity.get_component(Friction)

	# Reduces velocity speed over time based on the friction coefficient
	velocity.speed = max(0, velocity.speed - (friction.coefficient * delta))
