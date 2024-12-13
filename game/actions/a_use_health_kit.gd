class_name UseHealthKitAction
extends Action

func _meta():
    return {
        'name': "Use Healthkit",
        'description': "Heals a player with a health kit based on the passed in metdata of [Healthkit,Player].",
    }


func _action(_e) -> void:
    var health_kit = meta.get('item') as Entity
    var player = meta.get('player') as Entity
    if not health_kit or not player:
        return

    var c_health = player.get_component(C_Health) as C_Health
    c_health.current = c_health.total
    GameState.health_changed.emit(c_health.current)
    
    InventoryUtils.remove_inventory_item(health_kit)