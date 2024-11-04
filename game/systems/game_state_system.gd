## The game state system just runs all the time with the game state entity
class_name GameStateSystem
extends System

func _init():
	required_components = [GameState]


func process(entity: Entity, delta: float):
	pass
