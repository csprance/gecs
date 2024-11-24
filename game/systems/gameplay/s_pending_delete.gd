class_name PendingDeleteSystem
extends System

func query():
    return q.with_all([C_IsPendingDelete])

func process(entity, _delta: float):
    
    if entity.has_component(C_Item):
        GameState.inventory_item_removed.emit(entity)

    ECS.world.remove_entity(entity)
