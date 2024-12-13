class_name PickupSystem
extends System

var owned_by_player = Relationship.new(C_OwnedBy.new(), Player)

func query() -> QueryBuilder:
	return q.with_all([C_IsPickup, C_PickedUp]).with_relationship([owned_by_player])

func process(entity: Entity, _delta):
	var pickup = entity as Pickup
	if pickup.weapon_resource:
		pickup_weapon(pickup)
	if pickup.item_resource:
		pickup_item(pickup)
	
	# Remove the pickup entity from the world.
	ECS.world.remove_entity(pickup)

func pickup_weapon(pickup: Pickup):
	var player = pickup.get_relationship(owned_by_player).target
	assert(player, 'Player not found')
	if pickup.weapon_resource.pickup_action:
		pickup.weapon_resource.pickup_action.run_action()
	var new_weapon = Entity.new()
	new_weapon.name = pickup.weapon_resource.name
	new_weapon.add_components([pickup.weapon_resource, C_InInventory.new(), C_Quantity.new(pickup.quantity)])
	new_weapon.add_relationship(Relationship.new(C_OwnedBy.new(), player))
	Loggie.debug('Added weapon to inventory: ', new_weapon.name, ' Quantity: ', pickup.quantity)
	ECS.world.add_entity(new_weapon)
	GameState.inventory_weapon_added.emit(new_weapon)
	if not GameState.active_weapon:
		GameState.active_weapon = new_weapon
	
	return new_weapon

func pickup_item(pickup: Pickup):
	var player = pickup.get_relationship(owned_by_player).target
	assert(player, 'Player not found')
	if pickup.item_resource.pickup_action:
		pickup.item_resource.pickup_action.run_action()
	var new_item = Entity.new()
	new_item.name = '-'.join([pickup.item_resource.name, pickup.get_instance_id()])
	new_item.add_components([pickup.item_resource, C_InInventory.new(), C_Quantity.new(pickup.quantity)])
	new_item.add_relationship(Relationship.new(C_OwnedBy.new(), player))
	ECS.world.add_entity(new_item)
	GameState.inventory_item_added.emit(new_item)
	Loggie.debug('Added item to inventory: ', new_item.name, ' Quantity: ', pickup.quantity)
	GameState.inventory_item_added.emit(new_item)
	if not GameState.active_item:
		GameState.active_item = new_item
	
	return new_item
