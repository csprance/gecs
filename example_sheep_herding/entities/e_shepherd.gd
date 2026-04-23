@tool
class_name Shepherd
extends Entity


func define_components() -> Array:
	return [C_Shepherd.new(), C_Velocity.new()]
