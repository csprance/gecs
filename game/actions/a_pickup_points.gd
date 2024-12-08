class_name PickupPointsAction
extends Action

@export var points: int = 1


func execute(entities: Array) -> void:
    GameState.score += points