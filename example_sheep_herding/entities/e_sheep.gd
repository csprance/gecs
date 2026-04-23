@tool
class_name Sheep
extends Entity


func define_components() -> Array:
	return [
		C_Sheep.new(),
		C_SheepMovement.new(),
		C_SheepThreat.new(),
		C_Flocking.new(),
		C_Wander.new(),
		C_Velocity.new(),
	]
