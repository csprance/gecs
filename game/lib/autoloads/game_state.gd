# GameState Autoload
extends Node

signal radar_toggled

signal inventory_item_added(item: Entity)
signal inventory_item_removed(item: Entity)

signal game_paused
signal game_unpaused

signal health_changed(health: int)

signal score_changed(score: int)

signal lives_changed(lives: int)

signal weapon_changed(weapon: Entity)

signal item_changed(item: Entity)

var player : Entity:
	get:
		var players =  ECS.world.query.with_all([C_Player]).execute()
		if players.size() > 0:
			return players[0]
		return

var paused :bool = false:
	get:
		return paused
	set(v):
		paused = v
		if v:
			game_paused.emit()
		else:
			game_unpaused.emit()

var score :int = 0:
	get:
		return score
	set(v):
		score = v

var lives :int = 3 :
	get:
		return lives
	set(v):
		lives = v
		if lives == 0:
			print('Game Lost')


var active_weapon : Entity :
	get:
		var entities = ECS.world.query.with_all([C_Item, C_InInventory, C_IsActiveWeapon]).execute()
		if entities.size() > 0:
			return entities[0]
		GameState.player.remove_component(C_HasActiveWeapon)
		return 
	set(v):
		for e in ECS.world.query.with_all([C_Item, C_InInventory, C_IsActiveWeapon]).execute():
			e.remove_component(C_IsActiveWeapon)
		v.add_component(C_IsActiveWeapon.new())
		GameState.player.add_component(C_HasActiveWeapon.new())
		weapon_changed.emit(v)


var active_item: Entity :
	get:
		var entities = ECS.world.query.with_all([C_Item, C_InInventory, C_IsActiveItem]).execute()
		if entities.size() > 0:
			return entities[0]
		GameState.player.remove_component(C_HasActiveItem)
		return
	set(v):
		Loggie.debug('Setting active item: ', v)
		for e in ECS.world.query.with_all([C_Item, C_InInventory, C_IsActiveItem]).execute():
			e.remove_component(C_IsActiveItem)
		v.add_component(C_IsActiveItem.new())
		GameState.player.add_component(C_HasActiveItem.new())
		item_changed.emit(v)

## The current state of the world, use use_state to access this
var _state = {}



func get_inventory_items() -> Array:
	"""
	Returns an array of all items currently in the player's inventory.
	"""
	return ECS.world.query.with_all([C_Item, C_InInventory]).execute()
	

func add_inventory_item(c_item: C_Item, quantity: int = 1):
	"""
	Adds an item to the player's inventory.

	Parameters:
		c_item (C_Item): The item component to add.
		quantity (int): The quantity of the item to add.
	"""
	var new_item = Item.new()
	new_item.add_components([c_item, C_InInventory.new(), C_Quantity.new(quantity)])
	ECS.world.add_entity(new_item)
	inventory_item_added.emit(new_item)
	Loggie.debug('Added item to inventory: ', new_item.name, ' Quantity: ', quantity)
	return new_item

## Uses an item from the player's inventory.
## 
## Parameters:
## 	item (Entity): The item entity to use.
func use_inventory_item(item: Entity):
	var c_item = item.get_component(C_Item) as C_Item
	if c_item:
		Loggie.debug('Using Item', c_item)
		c_item.action.execute()
		
		item.add_component(C_IsPendingDelete.new())
		remove_inventory_item(item)
	else:
		Loggie.debug('Item does not have a C_Item component')

## Removes a specified quantity of an item from the player's inventory.
##
##	Parameters:
##		item (Entity): The item entity to remove.
##		remove_quantity (int): The quantity to remove.
func remove_inventory_item(item: Entity, remove_quantity = 1):	
	var c_item = item.get_component(C_Item) as C_Item
	var c_qty = item.get_component(C_Quantity) as C_Quantity
	var quantity = c_qty.value if c_qty else 1
	if c_item:
		if quantity >= remove_quantity:
			quantity -= remove_quantity
		if quantity == 0:
			item.add_component(C_IsPendingDelete.new())
			# TODO: Swap this to a different item?
			player.remove_component(C_HasActiveItem)

		Loggie.debug('Removing Item', c_item)
	else:
		Loggie.debug('Item does not have a C_Item component')

func cycle_inventory_item():
	"""
	Cycles to the next item in the player's inventory.
	"""
	var items = get_inventory_items()
	if items.size() > 0:
		var index = items.find(player.get_component(C_HasActiveItem))
		if index == -1:
			active_item = items[0]
		else:
			index += 1
			if index >= items.size():
				index = 0
			active_item = items[index]

## Access to the current active state of the ecs system
func use_state(entity: Entity, key: String, default_value = null) -> UseState:	
	"""
	Accesses or initializes a state associated with an entity.

	Parameters:
		entity (Entity): The entity to associate the state with.
		key (String): The key identifying the state.
		default_value: The default value to initialize if the state doesn't exist.

	Returns:
		UseState: A wrapper for the state value.
	"""
	return UseState.new(
		entity, 
		key, 
		default_value
	)

## A wrapper for the _state dictionary that allows you to use the state in a more object oriented way
class UseState:
	var key
	var entity
	var value: 
		get:
			return GameState._state[[entity, key]]
		set(_value):
			GameState._state[[entity, key]] = _value
	
	func _init(_entity, _key, default_value) -> void:
		key = _key
		entity = _entity
		if not GameState._state.has([entity, key]):
			GameState._state[[entity, key]] = default_value