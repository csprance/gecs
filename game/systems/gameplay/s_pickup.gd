class_name PickupSystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_IsPickup, C_PickedUp])

func process(entity: Entity, _delta):
	var pickup = entity as Pickup
	if pickup.weapon_resource:
		pickup_weapon(pickup)
	if pickup.item_resource:
		pickup_item(pickup)
	
	# Remove the pickup entity from the world.
	ECS.world.remove_entity(pickup)

func pickup_weapon(pickup: Pickup):
	if pickup.weapon_resource.pickup_action:
		pickup.weapon_resource.pickup_action.run()
	var new_weapon = Entity.new()
	new_weapon.add_components([pickup.weapon_resource, C_InInventory.new(), C_Quantity.new(pickup.quantity)])
	ECS.world.add_entity(new_weapon)
	if not GameState.active_weapon:
		GameState.active_weapon = new_weapon
	
	return new_weapon

func pickup_item(pickup: Pickup):
	if pickup.item_resource.pickup_action:
		pickup.item_resource.pickup_action.run()
	var new_item = Entity.new()
	new_item.add_components([pickup.item_resource, C_InInventory.new(), C_Quantity.new(pickup.quantity)])
	ECS.world.add_entity(new_item)
	GameState.inventory_item_added.emit(new_item)
	Loggie.debug('Added item to inventory: ', new_item.name, ' Quantity: ', 1)
	if not GameState.active_item:
		GameState.active_item = new_item
	
	return new_item