class_name UseSpeedShoesAction
extends InventoryAction


func _use_item(item: Entity, player: Entity) -> void:
    InventoryUtils.remove_inventory_item(item)
    player.add_component(C_Sprinting.new(2.0, 15.0, 1.0))