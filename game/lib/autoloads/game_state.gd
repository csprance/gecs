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
		return active_weapon
	set(v):
		active_weapon = v


var active_item: Entity :
	get:
		return active_item
	set(v):
		active_item = v

## The current state of the world, use use_state to access this
var _state = {}

func add_inventory_item(c_item: C_Item, quantity: int = 1):
	var new_item = Item.new()
	new_item.add_components([c_item, C_InInventory.new(), C_Quantity.new(quantity)])
	ECS.world.add_entity(new_item)
	inventory_item_added.emit(c_item)
	Loggie.debug('Added item to inventory: ', new_item.name, ' Quantity: ', quantity)

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