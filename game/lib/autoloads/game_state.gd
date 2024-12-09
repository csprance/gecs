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

signal weapon_fired(weapon: Entity)

signal item_used(item: Entity)


var player : Entity:
	get:
		var players =  Queries.is_players().execute()
		if players.size() > 0:
			return players[0]
		return

var player2 : Entity:
	get:
		var players =  Queries.is_players().execute()
		if players.size() > 1:
			return players[1]
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

## How many victims can spawn in the game in each level. Each victim that dies reduces this number. 
# Which means there are less victims that spawn in each level and less high score
var victims := 10:
	set(v):
		victims = v
		if v == 0:
			print('Game Lost All Victims Dead')

var score :int = 0:
	get:
		return score
	set(v):
		score = v
		score_changed.emit(v)


var lives :int = 3 :
	get:
		return lives
	set(v):
		lives = v
		if lives == 0:
			print('Game Lost')


var active_weapon : Entity :
	get:
		var entities = Queries.active_weapons().execute()
		if entities.size() > 0:
			return entities[0]
		return 
	set(v):
		for e in  Queries.active_weapons().execute():
			e.remove_component(C_IsActiveWeapon)
		v.add_component(C_IsActiveWeapon.new())
		GameState.player.add_component(C_HasActiveWeapon.new())
		weapon_changed.emit(v)


var active_item: Entity :
	get:
		var entities =  Queries.active_items().execute()
		if entities.size() > 0:
			return entities[0]
		return
	set(v):
		Loggie.debug('Setting active item: ', v)
		for e in  Queries.active_items().execute():
			e.remove_component(C_IsActiveItem)
		v.add_component(C_IsActiveItem.new())
		GameState.player.add_component(C_HasActiveItem.new())
		item_changed.emit(v)

var actions = []

## This is like Reacts useState hook, it allows you to store state on an entity
## entity (Entity): The entity to associate the state with.
## key (String): The key identifying the state.
## default_value: The default value to initialize if the state doesn't exist.
func use_state(entity: Entity, key: String, default_value = null) -> UseState:		
	return UseState.new(
		entity, 
		key, 
		default_value
	)

## A wrapper for the _state dictionary that allows you to use the state in a more object oriented way
class UseState:
	var _key: String
	var _entity: Entity
	
	var value: 
		get:
			return get_value()
		set(new_value):
			set_value(new_value)
	
	func _init(entity: Entity, key: String, initial_value = null) -> void:
		if entity == null:
			push_error("UseState: Entity cannot be null")
			return
			
		self._key = key
		self._entity = entity
		
		if not self._entity._state.has(key):
			set_value(initial_value)
	
	func get_value():
		if not self._entity._state.has(_key):
			push_warning("UseState: Accessing undefined state key '%s'" % _key)
			return null
		return self._entity._state[_key]
	
	func set_value(new_value) -> void:
		if self._entity == null:
			push_error("UseState: Cannot set value on null entity")
			return
		self._entity._state[_key] = new_value
	
	func has_value() -> bool:
		return self._entity._state.has(_key)
	
	func clear() -> void:
		self._entity._state.erase(_key)
