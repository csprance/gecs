class_name InventoryUtils


## Adds an item to the player's inventory.
## c_item (C_Item): The item component to add.
## quantity (int): The quantity of the item to add.
static func add_inventory_c_item(c_item: C_Item, quantity: int = 1):
	var new_item = Item.new()
	new_item.add_components([c_item, C_InInventory.new(), C_Quantity.new(quantity)])
	ECS.world.add_entity(new_item)
	GameState.inventory_item_added.emit(new_item)
	Loggie.debug('Added item to inventory: ', new_item.name, ' Quantity: ', quantity)
	return new_item

static func get_item_quantity(item: Entity) -> int:
	if not item:
		return 0
	var c_qty = item.get_component(C_Quantity) as C_Quantity
	return c_qty.value if c_qty else 1

## Uses an item from the player's inventory.
## 
## 	item (Entity): The item entity to use.
static func use_inventory_item(item: Entity, player: Entity):
	var action = get_item_action(item)
	Loggie.debug('Using Item', item)
	if action:
		# We execute the action with no entities, as the action should be able to find the entities it needs.
		action.run([], {'item': item, 'player': player, 'from': 'InventoryUtils.use_inventory_item'})
	
	remove_inventory_item(item)

static func get_item_action(item: Entity) -> Action:
	var c_item_weapon = get_item_or_weapon(item)
	if c_item_weapon:
		return c_item_weapon.action
	return

static func get_item_or_weapon(item:Entity):
	var c_item = item.get_component(C_Item) as C_Item
	var c_weapon = item.get_component(C_Weapon) as C_Weapon
	if c_item:
		return c_item
	if c_weapon:
		return c_weapon
	return

## Removes a specified quantity of an item from the player's inventory.
##
##	Parameters:
##		item (Entity): The item entity to remove.
##		remove_quantity (int): The quantity to remove.
static func remove_inventory_item(item: Entity, remove_quantity = 1):	
	var c_item_weapon = get_item_or_weapon(item)
	var c_qty = item.get_component(C_Quantity) as C_Quantity
	var quantity = c_qty.value if c_qty else 1
	if c_item_weapon:
		if quantity >= remove_quantity:
			quantity -= remove_quantity
		if quantity == 0:
			item.add_component(C_IsPendingDelete.new())
			# TODO: Swap this to a different item?
			GameState.player.remove_component(C_HasActiveItem)

		Loggie.debug('Removing Item', c_item_weapon)
	else:
		Loggie.debug('Item does not have a C_Item component')

## Cycles to the next item in the player's inventory.
static func cycle_inventory_item():
	var items =  Queries.all_items_in_inventory().execute()
	if items.size() > 0:
		var index = items.find(GameState.player.get_component(C_HasActiveItem))
		if index == -1:
			GameState.active_item = items[0]
		else:
			index += 1
			if index >= items.size():
				index = 0
			GameState.active_item = items[index]