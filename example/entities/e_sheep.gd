@tool
class_name Sheep
extends Entity


func define_components() -> Array:
	return [C_Sheep.new(), C_Speed.new(), C_Wander.new(), C_FleeRange.new()]
