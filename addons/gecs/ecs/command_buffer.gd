## CommandBuffer
##
## Queues structural changes (add/remove components, entities, relationships) for deferred execution.[br]
## Enables safe iteration by batching operations and executing them after system processing completes.[br]
## Commands execute in the order they were queued, preserving user intent.[br]
##
## [b]Problem it solves:[/b]
## - Eliminates need for backwards iteration during entity removal
## - Removes defensive snapshot overhead (O(N) memory)
## - Enables cross-entity batching for 10-50x performance gains on bulk operations
##
## [b]Example Usage:[/b]
##[codeblock]
##     func process(entities: Array[Entity], components: Array, delta: float) -> void:
##         for entity in entities:
##             if should_delete(entity):
##                 cmd.remove_entity(entity)  # Queued for later
##             if should_transform(entity):
##                 cmd.remove_component(entity, C_OldState)
##                 cmd.add_component(entity, C_NewState.new())
##         # Auto-executes after system completes (based on flush mode)
##[/codeblock]
class_name CommandBuffer
extends RefCounted

## Queued commands to execute (each callable performs one operation)
var _commands: Array[Callable] = []

## Reference to the world for executing commands
var _world: World = null

## Statistics for debugging (optional)
var _stats := {
	"commands_queued": 0,
	"commands_executed": 0,
	"last_execution_time_ms": 0.0,
}


func _init(world: World = null):
	_world = world if world else ECS.world


## Queue adding a component to an entity
func add_component(entity: Entity, component: Resource) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				entity.add_component(component)
	)
	_stats["commands_queued"] += 1


## Queue removing a component from an entity
func remove_component(entity: Entity, component_type: Variant) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				entity.remove_component(component_type)
	)
	_stats["commands_queued"] += 1


## Queue adding multiple components to an entity (batched per-entity)
func add_components(entity: Entity, components: Array) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				entity.add_components(components)
	)
	_stats["commands_queued"] += 1


## Queue removing multiple components from an entity (batched per-entity)
func remove_components(entity: Entity, component_types: Array) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				entity.remove_components(component_types)
	)
	_stats["commands_queued"] += 1


## Queue adding an entity to the world
func add_entity(entity: Entity) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				_world.add_entity(entity)
	)
	_stats["commands_queued"] += 1


## Queue removing an entity from the world
func remove_entity(entity: Entity) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				_world.remove_entity(entity)
	)
	_stats["commands_queued"] += 1


## Queue adding a relationship to an entity
func add_relationship(entity: Entity, relationship: Relationship) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				entity.add_relationship(relationship)
	)
	_stats["commands_queued"] += 1


## Queue removing a relationship from an entity
func remove_relationship(entity: Entity, relationship: Relationship, limit: int = -1) -> void:
	_commands.append(
		func():
			if is_instance_valid(entity):
				entity.remove_relationship(relationship, limit)
	)
	_stats["commands_queued"] += 1


## Queue a custom operation (for complex multi-step operations)
## The callable should take no parameters and perform the desired operation
func add_custom(callable: Callable) -> void:
	_commands.append(callable)
	_stats["commands_queued"] += 1


## Execute all queued commands in the order they were queued.[br]
## Cache invalidation is deferred until all commands complete for performance.
func execute() -> void:
	if _commands.is_empty():
		return

	var start_time := Time.get_ticks_usec()

	# Take ownership of the current queue before iterating. A queued command may
	# synchronously trigger observer dispatch (PER_CALLBACK flush reads
	# `has_pending_commands()`); if `_commands` still held this batch, the
	# reentrant `execute()` would re-run the same lambdas and recurse infinitely.
	# Commands queued during iteration land in a fresh `_commands` and are
	# flushed by the next `execute()` call.
	var to_run: Array[Callable] = _commands
	_commands = []

	# Suppress cache invalidation during batch execution; _end_suppress fires once at end.
	# Force _pending_invalidation so _end_suppress always fires exactly one invalidation —
	# commands always mutate state, so the cache must always be invalidated after execute().
	_world._begin_suppress()
	_world._pending_invalidation = true

	for callable in to_run:
		callable.call()

	_world._end_suppress()

	# Update statistics
	_stats["commands_executed"] += to_run.size()
	_stats["last_execution_time_ms"] = (Time.get_ticks_usec() - start_time) / 1000.0


## Clear all queued commands without executing them
func clear() -> void:
	_commands.clear()


## Check if there are any queued commands
func is_empty() -> bool:
	return _commands.is_empty()


## Get the number of queued commands
func size() -> int:
	return _commands.size()


## Get statistics for debugging (only useful when commands have been executed)
func get_stats() -> Dictionary:
	return _stats.duplicate()
