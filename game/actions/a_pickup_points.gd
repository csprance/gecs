class_name PickupPointsAction
extends Action


func execute(entities: Array) -> void:
    # whatever the first entity is give that entity points
    var player = meta.get('player', null)
    var pickup = meta.get('pickup', null)
    if player and pickup:
        GameState.score += pickup.points