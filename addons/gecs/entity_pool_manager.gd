## EntityPoolManager[br]
## Manages multiple entity pools for performance optimization.[br]
## Provides transparent entity pooling that maintains the exact same API.[br]
##
## The pool manager handles creation, reuse, and cleanup of entities behind the scenes[br]
## without requiring any changes to user code or API.
class_name EntityPoolManager
extends RefCounted

## Default pool name for general entities
const DEFAULT_POOL = "default"

## Pool configurations - Dictionary[pool_name: String, config: Dictionary]
var pool_configs: Dictionary = {}
## Active pools - Dictionary[pool_name: String, entities: Array[Entity]]
var pools: Dictionary = {}
## Pool size tracking
var pool_sizes: Dictionary = {}
## Pool usage statistics
var pool_stats: Dictionary = {}
## Logger for pool operations
var _poolLogger = GECSLogger.new().domain("EntityPool")

## Initialize the pool manager with default configuration
func _init():
	# Create default pool configuration
	configure_pool(DEFAULT_POOL, {
		"initial_size": 10,
		"max_size": 100,
		"grow_by": 5
	})

## Configure a pool with the given parameters
## [param pool_name] Name of the pool to configure
## [param config] Configuration dictionary with keys: initial_size, max_size, grow_by
func configure_pool(pool_name: String, config: Dictionary) -> void:
	pool_configs[pool_name] = config
	pool_stats[pool_name] = {
		"created": 0,
		"reused": 0,
		"returned": 0,
		"destroyed": 0
	}
	
	# Initialize the pool if it doesn't exist
	if not pools.has(pool_name):
		pools[pool_name] = []
		pool_sizes[pool_name] = 0
		_populate_pool(pool_name, config.get("initial_size", 10))

## Pre-populate a pool with entities
func _populate_pool(pool_name: String, count: int) -> void:
	_poolLogger.debug("Populating pool '%s' with %d entities" % [pool_name, count])
	
	var pool = pools[pool_name]
	for i in range(count):
		var entity = _create_fresh_entity()
		_reset_entity(entity)
		pool.append(entity)
		pool_sizes[pool_name] += 1

## Create a brand new entity (not from pool)
func _create_fresh_entity() -> Entity:
	return Entity.new()

## Reset an entity to a clean state for reuse
func _reset_entity(entity: Entity) -> void:
	# Reset entity state
	entity.enabled = true
	entity._state.clear()
	
	# Clear all components
	entity.remove_all_components()
	
	# Clear all relationships
	var relationships_to_remove = entity.relationships.duplicate()
	for relationship in relationships_to_remove:
		entity.remove_relationship(relationship)
	
	# Reset node properties
	entity.name = "ResetPoolEntity"
	entity.set_process(false)
	entity.set_physics_process(false)
	
	# Remove from tree if it's in the tree
	if entity.is_inside_tree():
		entity.get_parent().remove_child(entity)

## Get an entity from the specified pool
## [param pool_name] Name of the pool to get entity from
## [param entity_class] Optional entity class to instantiate if pool is empty
func get_entity(pool_name: String = DEFAULT_POOL, entity_class: Script = null) -> Entity:
	if not pools.has(pool_name):
		configure_pool(pool_name, {"initial_size": 5, "max_size": 50, "grow_by": 3})
	
	var pool = pools[pool_name]
	var entity: Entity
	
	# Try to get from pool first
	if not pool.is_empty():
		entity = pool.pop_back()
		pool_sizes[pool_name] -= 1
		pool_stats[pool_name]["reused"] += 1
		_poolLogger.trace("Reused entity from pool '%s'" % pool_name)
	else:
		# Pool is empty, create new entity
		if entity_class:
			entity = entity_class.new()
		else:
			entity = _create_fresh_entity()
		
		pool_stats[pool_name]["created"] += 1
		_poolLogger.trace("Created new entity for pool '%s'" % pool_name)
	
	# Reset the entity to clean state
	_reset_entity(entity)
	return entity

## Return an entity to the specified pool
## [param entity] The entity to return to the pool
## [param pool_name] Name of the pool to return entity to
func return_entity(entity: Entity, pool_name: String = DEFAULT_POOL) -> void:
	if not pools.has(pool_name):
		# Pool doesn't exist, just destroy the entity
		_destroy_entity(entity)
		return
	
	var pool = pools[pool_name]
	var config = pool_configs[pool_name]
	var max_size = config.get("max_size", 100)
	
	# Check if pool has room
	if pool_sizes[pool_name] < max_size:
		_reset_entity(entity)
		pool.append(entity)
		pool_sizes[pool_name] += 1
		pool_stats[pool_name]["returned"] += 1
		_poolLogger.trace("Returned entity to pool '%s'" % pool_name)
	else:
		# Pool is full, destroy the entity
		_destroy_entity(entity)
		pool_stats[pool_name]["destroyed"] += 1
		_poolLogger.trace("Pool '%s' full, destroyed entity" % pool_name)

## Destroy an entity completely
func _destroy_entity(entity: Entity) -> void:
	entity.on_destroy()
	entity.queue_free()

## Get pool statistics for monitoring
func get_pool_stats() -> Dictionary:
	return pool_stats.duplicate(true)

## Get current pool sizes
func get_pool_sizes() -> Dictionary:
	return pool_sizes.duplicate()

## Clear all entities from a specific pool
func clear_pool(pool_name: String) -> void:
	if not pools.has(pool_name):
		return
	
	var pool = pools[pool_name]
	for entity in pool:
		_destroy_entity(entity)
	
	pool.clear()
	pool_sizes[pool_name] = 0
	_poolLogger.debug("Cleared pool '%s'" % pool_name)

## Clear all pools
func clear_all_pools() -> void:
	for pool_name in pools.keys():
		clear_pool(pool_name)

## Grow a pool by the specified amount
func grow_pool(pool_name: String, additional_entities: int = -1) -> void:
	if not pools.has(pool_name):
		return
	
	var config = pool_configs[pool_name]
	var grow_amount = additional_entities if additional_entities > 0 else config.get("grow_by", 5)
	
	_populate_pool(pool_name, grow_amount)

## Optimize pools by removing excess entities
func optimize_pools() -> void:
	for pool_name in pools.keys():
		var pool = pools[pool_name]
		var config = pool_configs[pool_name]
		var initial_size = config.get("initial_size", 10)
		
		# If pool is larger than initial size, trim it down
		while pool.size() > initial_size:
			var entity = pool.pop_back()
			_destroy_entity(entity)
			pool_sizes[pool_name] -= 1
	
	_poolLogger.debug("Optimized all pools")

## Configure default entity pools based on frequency and size patterns
func configure_default_pools() -> void:
	# Default pool for general entities
	configure_pool("default", {
		"initial_size": 10,
		"max_size": 100,
		"grow_by": 5
	})
	
	# High-frequency, short-lived entities (bullets, particles, temporary effects)
	configure_pool("high_frequency", {
		"initial_size": 50,
		"max_size": 200,
		"grow_by": 20
	})
	
	# Medium-frequency entities (collectibles, spawned objects)
	configure_pool("medium_frequency", {
		"initial_size": 25,
		"max_size": 100,
		"grow_by": 10
	})
	
	# Low-frequency, longer-lived entities (NPCs, furniture, persistent objects)
	configure_pool("low_frequency", {
		"initial_size": 5,
		"max_size": 30,
		"grow_by": 3
	})

## Handle entity removal with pool consideration.[br]
## Returns true if entity was returned to pool, false if it should be destroyed normally.[br]
## [param entity] The entity to potentially return to pool.[br]
func handle_entity_removal(entity: Entity) -> bool:
	if entity.has_meta("_pool_hint"):
		var pool_name = entity.get_meta("_pool_hint")
		return_entity(entity, pool_name)
		_poolLogger.trace("Returned entity to pool '%s'" % pool_name)
		return true
	return false
