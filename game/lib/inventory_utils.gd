## This class is the main class for interacting with the player's inventory.[br]
## It consists of all static methods that are used to interact with any item in any player's inventory.[br]
class_name InventoryUtils

## Uses an item from the player's inventory.[br]
## This is the main way we interact with items in the player's inventory.[br]
## Calls the run_inventory_action method on the item's [Action].[br]
## Parameters:[br]
##   - item: The item [Entity] to use.[br]
##   - player: The player [Entity] using the [C_Item] from the `item`.
static func use_inventory_item(item: Entity, player: Entity):
	var action = get_item_action(item)
	if action:
		# pass in the item and the player.
		action.run_inventory_action([item], player)

	remove_inventory_item(item)

## Helper function to handle picking up resources (weapons and items).
static func pickup_resource(pickup: Pickup, resource_property: String, inventory_signal: Signal, active_resource_property: String):
	var player = pickup.get_relationship(Relationship.new(C_OwnedBy.new(), Player)).target
	assert(player, 'Player not found')

	var resource = pickup.get(resource_property)
	if resource.pickup_action:
		resource.pickup_action.run_action()

	var new_entity = Entity.new()
	new_entity.name = '-'.join([resource.name, str(pickup.get_instance_id())])

	new_entity.add_components([resource, C_InInventory.new(), C_Quantity.new(pickup.quantity)])
	if resource.hidden:
		new_entity.add_component(C_HideInQuickBar.new())
	new_entity.add_relationship(Relationship.new(C_OwnedBy.new(), player))

	ECS.world.add_entity(new_entity)
	inventory_signal.emit(new_entity)
	Loggie.debug('Added item to inventory: ', new_entity.name, ' Quantity: ', pickup.quantity)

	if not GameState.get(active_resource_property):
		GameState.set(active_resource_property, new_entity)

	return new_entity

## Adds a weapon to the player's inventory.
static func pickup_weapon(pickup: Pickup):
	return pickup_resource(
		pickup,
		"weapon_resource",
		GameState.inventory_weapon_added,
		"active_weapon"
	)

## Adds an item to the player's inventory.
static func pickup_item(pickup: Pickup):
	return pickup_resource(
		pickup,
		"item_resource",
		GameState.inventory_item_added,
		"active_item"
	)

## Gets the quantity of the specified item.[br]
## Parameters:[br]
##   - item: The item entity.[br]
## Returns:[br]
##   - The quantity of the item.
static func get_item_quantity(item: Entity) -> int:
	if not item:
		return 0
	var c_qty = item.get_component(C_Quantity) as C_Quantity
	return c_qty.value if c_qty else 1

## Gets the action associated with the item.[br]
## Parameters:[br]
##   - item: The item entity.[br]
## Returns:[br]
##   - The action associated with the item.
static func get_item_action(item: Entity) -> Action:
	var c_item_weapon = get_item_or_weapon(item)
	if c_item_weapon:
		return c_item_weapon.action
	assert(false, 'Item does not have an action')
	return

## Gets the item or weapon component from the entity.[br]
## Parameters:[br]
##   - [item]: The item entity.[br]
## Returns:[br]
##   - The [C_Item] or [C_Weapon] [Component].
static func get_item_or_weapon(item:Entity):
	var c_item = item.get_component(C_Item) as C_Item
	if c_item:
		return c_item
	var c_weapon = item.get_component(C_Weapon) as C_Weapon
	if c_weapon:
		return c_weapon
	return

## Removes a specified quantity of an item from the player's inventory.[br]
## If the quantity is 0, the item is removed from the player's inventory.[br]
## Parameters:[br]
##   - [item]: The item entity to remove.[br]
##   - [remove_quantity]: The quantity to remove.
static func remove_inventory_item(item: Entity, remove_quantity = 1):	
	var c_item_weapon = get_item_or_weapon(item)
	var c_qty = item.get_component(C_Quantity) as C_Quantity
	var quantity = c_qty.value if c_qty else 1
	if c_item_weapon:
		if quantity >= remove_quantity:
			quantity -= remove_quantity
		if quantity == 0:
			item.add_component(C_IsPendingDelete.new())
			if item.has_component(C_IsActiveItem) :
				GameState.active_item = null
			if item.has_component(C_IsActiveWeapon):
				GameState.active_weapon = null

		Loggie.debug('Removing Item', c_item_weapon)
		GameState.inventory_item_removed.emit(item)
	else:
		Loggie.debug('Item does not have a C_Item component')

## Cycles to the next item in the player's inventory.
static func cycle_inventory_item():
	consolidate_inventory()
	var items =  Queries.in_inventory_of_entity(GameState.player).combine(Queries.is_item()).combine(Queries.shows_in_quickbar()).execute()
	# Find the active item and set the next item as the active item
	for item in items:
		if item.has_component(C_IsActiveItem):
			var next_index = (items.find(item) + 1) % items.size()
			GameState.active_item = items[next_index]
			return
		else:
			GameState.active_item = items[0]


## Cycles to the next weapon in the player's inventory.
static func cycle_inventory_weapon():
	consolidate_inventory()
	var weapons =  Queries.in_inventory_of_entity(GameState.player).combine(Queries.is_weapon()).combine(Queries.shows_in_quickbar()).execute()
	# Find the active weapon and set the next weapon as the active weapon
	for weapon in weapons:
		if weapon.has_component(C_IsActiveWeapon):
			var next_index = (weapons.find(weapon) + 1) % weapons.size()
			GameState.active_weapon = weapons[next_index]
			return
		else:
			GameState.active_weapon = weapons[0]

## Consolidates the player's inventory.[br]
## This will consolidate all items that have the same item component.[br]
## This is useful for when the player picks up multiple items of the same type.[br]
## For example, if the player picks up 3 health potions, this will consolidate them into a single entity with a quantity of 3.
static func consolidate_inventory():
	var inventory_entities = Queries.in_inventory_of_entity(GameState.player).execute()
	var item_quantities = {}
	var entities_to_remove = []

	# Sum quantities for each unique c_item
	for entity in inventory_entities:
		var c_item = get_item_or_weapon(entity)
		if c_item:
			var quantity = get_item_quantity(entity)
			if c_item in item_quantities:
				# Add quantity to existing entry
				item_quantities[c_item]["quantity"] += quantity
				entities_to_remove.append(entity)  # Mark duplicate entity for removal
			else:
				# Create new entry for unique item
				item_quantities[c_item] = {"entity": entity, "quantity": quantity}

	# Remove duplicate entities
	for entity in entities_to_remove:
		ECS.world.remove_entity(entity)

	# Update quantities of remaining entities
	for item_data in item_quantities.values():
		var entity = item_data["entity"]
		var qty = item_data["quantity"]
		entity.add_component(C_Quantity.new(qty))
