@tool
class_name HerderPlayer
extends Entity


func define_components() -> Array:
	return [C_Player.new(), C_Speed.new()]
