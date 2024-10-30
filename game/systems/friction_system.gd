## This is the Friction System it is reponsible for reducing the velocity Component
## based on the Friction Coeffecnient set in the Friction Component
class_name FrictionSystem
extends System


func on_process_entity(entity : Entity, delta: float):
	var velocity: Velocity = entity.get_component("velocity")
	var friction: Friction = entity.get_component("friction")
	
	# Reduces velocity speed over time based on the friction coefficient
	velocity.speed = max(0, velocity.speed - (friction.coefficient * delta))
