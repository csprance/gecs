class_name PickupPointsAction
extends Action

@export var points: int = 1


func _action(entities: Array) -> void:
    GameState.score += points