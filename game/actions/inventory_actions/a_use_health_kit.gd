class_name UseHealthKitAction
extends InventoryAction

func _meta():
    return {
        'name': "Use Healthkit",
        'description': "Heals a player with a health kit based on the passed in metdata of [Healthkit,Player].",
    }


func _use_item(health_kit: Entity, player: Entity) -> void:
    var c_health = player.get_component(C_Health) as C_Health
    c_health.current = c_health.total
    GameState.health_changed.emit(c_health.current)
    
    InventoryUtils.remove_inventory_item(health_kit)