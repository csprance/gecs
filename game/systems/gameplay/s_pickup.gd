class_name PickupSystem
extends System

var owned_by_player = Relationship.new(C_OwnedBy.new(), Player)

func query() -> QueryBuilder:
	return q.with_all([C_IsPickup, C_PickedUp]).with_relationship([owned_by_player])

func process(entity: Entity, _delta):
	var pickup = entity as Pickup
	
	if pickup.item_resource is C_Weapon:
		InventoryUtils.pickup_weapon(pickup)	
	elif pickup.item_resource is C_Item:
		InventoryUtils.pickup_item(pickup)	
	
	# Remove the pickup entity from the world.
	ECS.world.remove_entity(pickup)

