class_name ItemPickedUpSystem
extends System


func query() -> QueryBuilder:
    return q.with_all([C_PickUp, C_PickedUp])

func process(entity: Entity, _delta):
    var pickup = entity as Pickup
    var c_item = pickup.item_resource
    # Create and add our item to the player's inventory.
    Utils.add_inventory_item(c_item)
    # Remove the pickup entity from the world.
    ECS.world.remove_entity(pickup)