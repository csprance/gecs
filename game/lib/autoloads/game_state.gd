# GameState Autoload
extends Node

signal inventory_item_added(item: Entity)
signal inventory_item_removed(item: Entity)

signal game_paused
signal game_unpaused

signal score_changed(score: int)

signal lives_changed(lives: int)

signal weapon_changed(weapon: Entity)

signal item_changed(item: Entity)

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
		return
	set(v):
		for e in ECS.world.query.with_all([C_Item, C_InInventory, C_IsActiveWeapon]).execute():
			e.remove_component(C_IsActiveWeapon)
		v.add_component(C_IsActiveWeapon.new())


var active_item: Entity :
	get:
		var entities = ECS.world.query.with_all([C_Item, C_InInventory, C_IsActiveItem]).execute()
		if entities.size() > 0:
			return entities[0]
		return
	set(v):
		for e in ECS.world.query.with_all([C_Item, C_InInventory, C_IsActiveItem]).execute():
			e.remove_component(C_IsActiveItem)
		v.add_component(C_IsActiveItem.new())

## The current state of the world, use use_state to access this
var _state = {}


func get_inventory_items() -> Array:
	return ECS.world.query.with_all([C_Item, C_InInventory]).execute()
	

func add_inventory_item(c_item: C_Item, quantity: int = 1):
	var new_item = Item.new()
	new_item.add_components([c_item, C_InInventory.new(), C_Quantity.new(quantity)])
	ECS.world.add_entity(new_item)
	inventory_item_added.emit(new_item)
	Loggie.debug('Added item to inventory: ', new_item.name, ' Quantity: ', quantity)
	return new_item

func remove_inventory_item(c_item: C_Item, quantity: int = 1):
	for entity in ECS.world.query.with_all([c_item, C_InInventory]).execute():
		var c_quantity = entity.get_component(C_Quantity) as C_Quantity
		if c_quantity.quantity >= quantity:
			c_quantity.quantity -= quantity
			Loggie.debug('Removed item from inventory: ', entity.name, ' Quantity: ', quantity)
			inventory_item_removed.emit(c_item)
			if c_quantity.quantity <= 0:
				ECS.world.remove_entity(entity)
			return
		else:
			Loggie.debug('Not enough items to remove from inventory: ', entity.name, ' Quantity: ', quantity)
			return
	Loggie.debug('Item not found in inventory: ', c_item.name)


## Access to the current active state of the ecs system
func use_state(entity: Entity, key: String, default_value = null) -> UseState:	
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